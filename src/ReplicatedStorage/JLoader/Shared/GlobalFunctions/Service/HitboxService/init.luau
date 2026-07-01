-- Created Date: Thursday November 23rd 2023 3:14:04 pm CEST
-- Original Author: Jurian Vierbergen at <VoidedBlades (Rbx), @VoidedBlades (Twitter)> ( Shoutout my boy)

local RunService = game:GetService("RunService")
local Signal = require(script.Parent.Parent.Signal)

local FORCE_DEBUG = RunService:IsStudio()

-- TODO: add sphere option
export type HitboxType = "Sphere" | "Box" | "Cylinder"

type Hitbox = {
	Attacker: Model,
	ActivationTime: number?,
	MaxTargets: number?,
	Offset: Vector3?,
	MaxHitsPerTarget: number?,
	HitboxPart: (BasePart | Attachment)?,
	CollisionGroup: string?,
	CFrame: CFrame? | () -> CFrame,
}

export type SphereHitboxData = Hitbox & {
	Radius: number,
}
export type CylinderHitboxData = Hitbox & {
	Radius: number,
	Height: number,
}
export type BoxHitboxData = Hitbox & {
	Size: Vector3,
}

local hitboxes = {}
local hitboxTypes = {}
local module = {}

local function GetCFrame(self)
	if self._data.CFrame then
		if self._data.CFrameType == "function" then
			return self._data.CFrame()
		end
		return self._data.CFrame
	end

	local hitboxPart: Instance = self._data.HitboxPart

	if hitboxPart:IsA("BasePart") then
		return hitboxPart.CFrame
	elseif hitboxPart:IsA("Attachment") then
		return hitboxPart.WorldCFrame
	end

	return
end

local function TableLength(tbl: { any }): number
	local count = 0
	for _ in tbl do
		count += 1
	end

	return count
end

function module.New(
	type: HitboxType,
	data: SphereHitboxData | CylinderHitboxData | BoxHitboxData,
	whiteList: { Instance }?,
	blacklist: { Instance }?,
	sharedHitRegistery: {}? -- useful if multiple hitbox shapes are needed to make them act as 1
): { onDispose: Signal.Signal, onHit: Signal.Signal } & typeof(module)
	data.MaxTargets = data.MaxTargets or -1
	data.MaxHitsPerTarget = data.MaxHitsPerTarget or 1

	data.Debug = FORCE_DEBUG

	local self = setmetatable({
		onDispose = Signal.new(),
		onHit = Signal.new(),
		onStart = Signal.new(),

		Started = false,
		Paused = false,
		ActivationTime = data.ActivationTime or 0,

		_hitbox = hitboxTypes[type],
		_hitboxType = type,
		_hitRegistry = sharedHitRegistery or {},
		_hitRegistryCount = 0,
		_blackList = blacklist or {},
		_whiteList = whiteList or { workspace:WaitForChild("Living") },
		_data = data,
		_HitboxPoints = {},
	}, { __index = module })

	if not self._data.CFrame and self._data.HitboxPart == nil then
		self._data.HitboxPart = self._data.Attacker.PrimaryPart
		-- self._data.CFrame = self._data.Attacker.PrimaryPart.CFrame
		-- self.DynamicPlacement = true
	end

	local cfType = typeof(self._data.CFrame)
	self._data.CFrameType = cfType

	if cfType == "function" then
		cfType = typeof(self._data.CFrame())
	end

	if self._data.CFrame then
		if self._data.CFrameType ~= "function" and cfType ~= "CFrame" then
			error("Index CFrame does not return a CFrame")
		elseif cfType ~= "CFrame" then
			error("Index CFrame is not a CFrame")
		end
	end

	if self._hitboxType == "Sphere" then
		self._data.Size = Vector3.one * self._data.Radius
	end

	table.insert(hitboxes, self)

	return self
end
local function Project(a, normal)
	local normalized = vector.normalize(normal)
	return normalized * vector.dot(normalized, a)
end

local function ProjectPointInPlane(data, pointToProject)
	return (pointToProject - Project(pointToProject - data.Position, data.Normal))
end

local function GetClosesPointOnDisc(a: vector, b: vector, radius)
	local plane = {
		Position = a,
		Normal = vector.normalize(b - a),
	}
	local vProjected = ProjectPointInPlane(plane, b)

	local distSquared = math.sqrt(vector.dot(vProjected, vProjected))
	local isInsideShape = distSquared < math.sqrt(radius)
	if isInsideShape then
		return vProjected, true
	end
	local pointExtremity = plane.Position + vector.normalize(vProjected - plane.Position) * radius
	return pointExtremity, false
end

local function GetclosesPoint(point, size, v)
	local p1 = point - vector.create(0, size.Y / 2, 0)
	local p2 = point + vector.create(0, size.Y / 2, 0)

	local delta = p2 - p1
	local deltaSquared = vector.dot(delta, delta)
	local dist = vector.dot(v - p1, delta)
	if dist <= 0 then
		return GetClosesPointOnDisc(p1, v, size.X)
	elseif dist >= deltaSquared then
		return GetClosesPointOnDisc(p2, v, size.X)
	else
		dist = dist / deltaSquared
		local pointOnLine = p1 + dist * delta
		local pointOnSurfaceLine = pointOnLine + (vector.normalize(v - pointOnLine) * size.X)
		return pointOnSurfaceLine, true
	end
end

function module:IsInsideHitbox(from: vector)
	local targetCF = GetCFrame(self)
	local objectSpaceFrom = targetCF:PointToObjectSpace(from)

	if self._hitboxType == "Box" then
		local targetSize = self._data.Size / 2
		local abs = vector.abs(objectSpaceFrom)

		if abs.X < targetSize.X and abs.Y < targetSize.Y and abs.Z < targetSize.Z then
			return true
		end

		return false
	elseif self._hitboxType == "Sphere" then
		return vector.magnitude(from - targetCF.Position) < self._data.Radius
	elseif self._hitboxType == "Cylinder" then
		local point, isInside = GetclosesPoint(targetCF.Position, self._data.Size, from)
		return isInside
	end

	return
end

function module:GetDistanceFromPoint(from: vector)
	local targetCF = GetCFrame(self)

	local objectSpaceFrom = targetCF:PointToObjectSpace(from)

	if self._hitboxType == "Box" then
		local targetSize = self._data.Size / 2

		local follow = vector.clamp(objectSpaceFrom, -targetSize, targetSize)

		local adjustedPosition = targetCF:PointToWorldSpace(follow)
		local calc = from - adjustedPosition
		local magnitude = vector.magnitude(calc)
		local direction = vector.normalize(calc)

		return magnitude, direction
	elseif self._hitboxType == "Sphere" then
		local calc = from - targetCF.Position
		local magnitude = vector.magnitude(calc)
		local direction = vector.normalize(calc)

		return magnitude - self._data.Radius / 2, direction
	elseif self._hitboxType == "Cylinder" then
		local location = GetclosesPoint(targetCF.Position, self._data.Size, from)

		local adjustedPosition = targetCF:PointToWorldSpace(location)
		local calc = from - adjustedPosition

		local magnitude = vector.magnitude(calc)
		local direction = vector.normalize(calc)

		return magnitude, direction
	end

	return
end

function module:Pause()
	self.Paused = true
end

function module:UnPause()
	self.Paused = false
end

function module:Dispose()
	if self.Disposed then
		return
	end

	local index = table.find(hitboxes, self)
	if index then
		table.remove(hitboxes, index)
	end
	self.Disposed = true
	self.onDispose:Fire()

	self.onHit:Destroy()
	self.onDispose:Destroy()
end

function module:UpdateCFrame(cf)
	self._data.CFrame = cf
end

function module:GetHitRegistery()
	return table.clone(self._hitRegistry)
end

function module:AddInstanceToWhitelist(instance: Instance)
	table.insert(self._whiteList, instance)
end

function module:AddInstanceToBlacklist(instance: Instance)
	table.insert(self._blackList, instance)
end

function module:Update(serverTimeNow, delta)
	if not self.Started then
		if serverTimeNow > self.ActivationTime then
			self.onStart:Fire()
			self.Started = true
		else
			return
		end
	end
	
	local results = self._hitbox(self._data, self._whiteList, self._blackList)

	if results then
		if
			self._data.MaxTargets ~= -1
			and (if self._hitRegistry then self._hitRegistryCount >= self._data.MaxTargets else true)
		then
			return
		end

		local function Check(Target: Model | Instance): (boolean, boolean?)
			if
				self._data.MaxHitsPerTarget ~= -1
				and self._hitRegistry[Target]
				and self._hitRegistry[Target] >= self._data.MaxHitsPerTarget
			then
				return false
			end

			if self._hitRegistry[Target] then
				self._hitRegistry[Target] += 1
			else
				self._hitRegistry[Target] = 1
				self._hitRegistryCount += 1
			end

			return true
		end
		
		if typeof(results) == "Instance" then
			local pass = Check(results)
			if not pass then
				return
			else
				self.onHit:Fire(results)
			end
		elseif typeof(results) == "table" then
			if TableLength(results) == 0 then
				return
			end
			for i, Target in results do
				local pass = Check(Target)
				if not pass then
					table.remove(results, i)
				else
					self.onHit:Fire(Target)
				end
			end
		end

		if not results then
			return
		end
	end
end

local t = 0
RunService.PreSimulation:Connect(function(a0: number)
	t += a0
	for _, hitbox in hitboxes do
		if not hitbox.Disposed and not hitbox.Paused then
			hitbox:Update(t, a0)
		end
	end
end)

for _, v in script.Types:GetChildren() do
	if v:IsA("ModuleScript") then
		hitboxTypes[v.Name] = require(v)
	end
end

return module
