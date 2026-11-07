local RayModule = {}

RayModule.world_ray_params = RaycastParams.new()
RayModule.world_ray_params.FilterType = Enum.RaycastFilterType.Include
RayModule.world_ray_params.FilterDescendantsInstances = {workspace:WaitForChild("World"):WaitForChild("Map")}
RayModule.world_ray_params.IgnoreWater = true
RayModule.world_ray_params.RespectCanCollide = true

--// Ray Debugging
RayModule.DebugRays = false

function DebugRay(ray, RayProperties, Remove)
	local Distance = (ray.Origin - RayProperties.Position).Magnitude

	local DebugRay = Instance.new("Part",workspace.World.Visuals)
	DebugRay.BrickColor = BrickColor.new("Bright red")
	DebugRay.FormFactor = "Custom"
	DebugRay.Material = "Neon"
	DebugRay.Transparency = 0.25
	DebugRay.Anchored = true
	DebugRay.Locked = true
	DebugRay.CanCollide = false
	DebugRay.Size = Vector3.new(0.1, 0.1, Distance)
	DebugRay.CFrame = CFrame.new(ray.Origin, RayProperties.Position) * CFrame.new(0, 0, -Distance / 2)

	if Remove then
		task.delay(0.25, DebugRay.Destroy, DebugRay)
	end
	
	if RayProperties.Hit then
		DebugRay.BrickColor = BrickColor.new("Bright green")
	end
end

--// Ray Checks
function ReturnRay(Character, RayCheck)
	local ignore = {workspace.World.Visuals, workspace.World.Live}
	local Hit, Position, Normal = workspace:FindPartOnRayWithIgnoreList(RayCheck, ignore, false, true)
	local RayProperties = {Hit = Hit, Position = Position, Normal = Normal}
	
	if RayModule.DebugRays then
		DebugRay(RayCheck, RayProperties, true)
	end

	return RayProperties
end

--Custom Ray
function RayModule.SetCustomRay(Character : Model, Configurations : Array)
	local Origin = Configurations.Origin
	local Direction = Configurations.Direction
	
	local SetRaycast = Ray.new(Origin, Direction)
	return ReturnRay(Character, SetRaycast)
end

--Top Ray
function RayModule.CeilingRay(Character, Length)
	local CeilingCheck = Ray.new((Character.HumanoidRootPart.CFrame * CFrame.new(0,2.7,0)).Position, Character.HumanoidRootPart.CFrame.UpVector * (Length or 6.5))
	return ReturnRay(Character, CeilingCheck)
end

--Ledge Rays
function RayModule.FrontLedgeRay(Character, Length)
	local LedgeCheck = Ray.new((Character.HumanoidRootPart.CFrame * CFrame.new(0,1.75,-2.5)).Position, Character.HumanoidRootPart.CFrame.UpVector * (Length or -2.75))
	return ReturnRay(Character, LedgeCheck)
end

function RayModule.BackLedgeRay(Character, Length)
	local LedgeCheck = Ray.new((Character.HumanoidRootPart.CFrame * CFrame.new(0,1.75,2.5)).Position, Character.HumanoidRootPart.CFrame.UpVector * (Length or -2.75))
	return ReturnRay(Character, LedgeCheck)
end

function RayModule.RightLedgeRay(Character, Length)
	local LedgeCheck = Ray.new((Character.HumanoidRootPart.CFrame * CFrame.new(-2.5,1.75,0)).Position, Character.HumanoidRootPart.CFrame.UpVector * (Length or -2.75))
	return ReturnRay(Character, LedgeCheck)
end

function RayModule.LeftLedgeRay(Character, Length)
	local LedgeCheck = Ray.new((Character.HumanoidRootPart.CFrame * CFrame.new(2.5,1.75,0)).Position, Character.HumanoidRootPart.CFrame.UpVector * (Length or -2.75))
	return ReturnRay(Character, LedgeCheck)
end

--Directional Rays
function RayModule.FrontRay(Character, Length)
	local RayCheck = Ray.new(Character.HumanoidRootPart.Position, Character.HumanoidRootPart.CFrame.LookVector * (Length or 2.5))
	return ReturnRay(Character, RayCheck)
end

function RayModule.BackRay(Character, Length)
	local RayCheck = Ray.new(Character.HumanoidRootPart.Position, Character.HumanoidRootPart.CFrame.LookVector * (Length or -2.5))
	return ReturnRay(Character, RayCheck)
end

function RayModule.RightRay(Character, Length)
	local RayCheck = Ray.new(Character.HumanoidRootPart.Position, Character.HumanoidRootPart.CFrame.RightVector * (Length or 2.5))
	return ReturnRay(Character, RayCheck)
end

function RayModule.LeftRay(Character, Length)
	local RayCheck = Ray.new(Character.HumanoidRootPart.Position, Character.HumanoidRootPart.CFrame.RightVector * (Length or -2.5))
	return ReturnRay(Character, RayCheck)
end

--Bottom Ray
function RayModule.FloorRay(Character, Length)
	local FloorCheck = Ray.new((Character.HumanoidRootPart.CFrame * CFrame.new(0,-2.5,0)).Position, Character.HumanoidRootPart.CFrame.UpVector * (-Length or -3))
	return ReturnRay(Character, FloorCheck)
end

function RayModule.FloorPosition(Position, Length)
	local FloorCheck = Ray.new((Position).Position, Position.UpVector * (-Length or -3))
	return ReturnRay(Position, FloorCheck)
end

return RayModule