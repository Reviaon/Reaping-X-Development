-- @ Start
local PhysicsService = {}

-- @ Services
local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Debris = game:GetService("Debris");
local RunService = game:GetService("RunService");
local UserInputService = game:GetService("UserInputService");
local TweenService = game:GetService("TweenService");

--@ Modules
local Modules = ReplicatedStorage:WaitForChild("Modules");

--@ Import
local Jloader = require(ReplicatedStorage.JLoader)
local GlobalFunctions = Jloader.GlobalFunctions;

local CharacterService = GlobalFunctions.CharacterService;
local WorldConstants = GlobalFunctions.WorldConstants;
local DestructionConstants = GlobalFunctions.DestructionConstants;

-- @ Variables


function PhysicsService.ProcessPhysics(character: Model, child: Instance)
	local root: BasePart = character:FindFirstChild("HumanoidRootPart")
	local humanoid: Humanoid = character:FindFirstChild("Humanoid")

	if child.Name == "@apply_impulse" then
		local exist_mover = root:FindFirstChild("@impulse_velocity")
		if exist_mover then
			exist_mover:Destroy()
		end

		local velocity = child:GetAttribute("velocity")
		local duration = child:GetAttribute("duration")
		local force_scale = child:GetAttribute("force_scale") or Vector3.new(1, 1, 1)
		local angular_scale = child:GetAttribute("angular_scale") or .5
		local look_at = child:GetAttribute("look_at")
		local stop_on_obstacle = child:GetAttribute("stop_on_obstacle")
		local hold_position_on_obstacle = child:GetAttribute("hold_position_on_obstacle")
		local obstacle_speed_quota = child:GetAttribute("obstacle_speed_quota") or 10
		local obstacle_check_duration = child:GetAttribute("obstacle_check_duration") or 2
		local start_cframe = child:GetAttribute("start_cframe")

		local power = child:GetAttribute("power")
		local fadeoff = child:GetAttribute("fadeoff")
		local nofloat_onYAxis = child:GetAttribute("nofloat_onYAxis")

		if start_cframe then 
			character:PivotTo(start_cframe)
		end

		for _, part: BasePart in ipairs(character:GetChildren()) do
			if not part:IsA("BasePart") then continue end
			part.AssemblyLinearVelocity = Vector3.zero

			if angular_scale > 0 then
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end

		local linear_velocity = Instance.new("BodyVelocity")
		linear_velocity:SetAttribute("knockback_mover", true)
		linear_velocity.Name = "@impulse_velocity"

		--linear_velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		linear_velocity.MaxForce = Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * force_scale * 4e4

		if nofloat_onYAxis then
			linear_velocity.MaxForce = Vector3.new(root.AssemblyMass, 0, root.AssemblyMass) * force_scale * 4e4
		end

		if fadeoff and power then
			linear_velocity.Velocity = velocity * power;

			local decreasepowertime = Instance.new("NumberValue");
			decreasepowertime.Value = power;
			decreasepowertime.Parent = linear_velocity;
			decreasepowertime.Name = "@decrease_power";

			TweenService:Create(decreasepowertime, TweenInfo.new(fadeoff, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Value = 0
			}):Play();

			decreasepowertime:GetPropertyChangedSignal("Value"):Connect(function()
				linear_velocity.Velocity = velocity * decreasepowertime.Value
			end);
		else
			linear_velocity.Velocity = velocity
		end

		linear_velocity.Parent = root

		local angular
		if angular_scale > 0 then
			angular = Instance.new("BodyAngularVelocity")
			angular:SetAttribute("knockback_mover", true)
			angular.Name = "@impulse_velocity"
			angular.MaxTorque = Vector3.new(15000, 15000, 15000) * root.AssemblyMass
			angular.AngularVelocity = -velocity:Cross(root.CFrame.UpVector) * angular_scale
			angular.Parent = root
		end

		if look_at and velocity.Magnitude > 0 then
			root.CFrame = CFrame.lookAt(root.Position,Vector3.new(look_at.X,root.Position.Y,look_at.Z))
		end

		task.spawn(function()
			task.wait(1/60)

			if angular and angular.Parent then
				angular:Destroy()
			end
		end)

		task.spawn(function()
			task.wait(duration or 1/60)

			linear_velocity:Destroy()
		end)

		if stop_on_obstacle then
			local end_time = os.clock() + obstacle_check_duration
			while os.clock() <= end_time do
				RunService.Heartbeat:Wait()

				local velocity = root.AssemblyLinearVelocity
				if velocity.Magnitude < obstacle_speed_quota then continue end

				local check_scaling = math.clamp(velocity.Magnitude / 50, 1, math.huge)

				local Params = RaycastParams.new()
				Params.FilterType = Enum.RaycastFilterType.Exclude
				Params.FilterDescendantsInstances = {character}
				Params.IgnoreWater = true
				Params.RespectCanCollide = true

				local wall = workspace:Blockcast(root.CFrame - velocity.Unit, root.Size, velocity, Params)
				
				if wall and wall.Distance <= (RunService:IsServer() and 5 or 15) * check_scaling then
					local model = wall.Instance:FindFirstAncestorOfClass("Model")
					if model and model:GetAttribute("class_type") == "Destructable" then
						local weight_class = model:GetAttribute("weight_class")
						local weight_data = DestructionConstants.weight_classes[weight_class]

						if velocity.Magnitude >= weight_data.velocity then
							wall.Instance.CanCollide = false

							if model:GetAttribute("destroyed") then
								continue
							end
						end
					end

					if wall.Distance > 15 then continue end

					if RunService:IsServer() then
						local CharacterController = GlobalFunctions.ProfileHandler:GetProfile(character)
						if not CharacterController then continue end

						--GlobalFunctions.EffectService:Fire({
						--	Player = nil, 
						--	Victim = character, 

						--	EffectName = "KnockbackImpactEffect",

						--	Extra = {
						--		ResultInstance = wall.Instance,
						--		ResultPosition = wall.Position,
						--		ResultNormal = wall.Normal,
						--		ResultMaterial = wall.Material,
						--		ResultDistance = wall.Distance
						--	}
						--})

						--CharacterController.ApplyPhysics(character,{
						--	Settings = {
						--		velocity = wall.Normal.Y > 0.35 and wall.Normal * 0 or wall.Normal * 0,
						--		duration = 0.2,

						--		stop_on_obstacle = true,
						--		obstacle_check_duration = 0,
						--		obstacle_speed_quota = 20,
						--	}
						--})
						
						--if linear_velocity then
						--	linear_velocity.Velocity = Vector3.new(0,0,0)
						--end
						
					else
						--@ Replicate On Client
					end

					if hold_position_on_obstacle then
						if linear_velocity and linear_velocity.Parent then
							linear_velocity:Destroy()
						end

						local linear_velocity = Instance.new("BodyVelocity")
						linear_velocity:SetAttribute("knockback_mover", true)
						linear_velocity.Name = "@impulse_velocity"
						--linear_velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
						linear_velocity.MaxForce = Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * 4e4
						linear_velocity.Velocity = velocity / 2
						linear_velocity.Parent = root
						Debris:AddItem(linear_velocity, hold_position_on_obstacle)

						TweenService:Create(linear_velocity, TweenInfo.new(.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
							Velocity = Vector3.zero
						}):Play()

						task.wait(hold_position_on_obstacle)
					end

					break
				end
			end
		end

		Debris:AddItem(child, .1)
	elseif child.Name == "@gravity_force" then
		local exist_mover = root:FindFirstChild("@gravity_force")
		if exist_mover then
			exist_mover:Destroy()
		end

		local duration = child:GetAttribute("duration")
		local gravity_force = child:GetAttribute("gravity_force")

		local linear_velocity = Instance.new("BodyForce")
		linear_velocity:SetAttribute("knockback_mover", true)
		linear_velocity.Name = "@gravity_force"
		linear_velocity.Force = Vector3.new(0, root.AssemblyMass, 0) * gravity_force * workspace.Gravity
		linear_velocity.Parent = root
		Debris:AddItem(linear_velocity, duration)
	elseif child.Name == "@apply_angular_impulse" then
		local exist_mover = root:FindFirstChild("@impulse_velocity")
		if exist_mover then
			exist_mover:Destroy()
		end

		local velocity = child:GetAttribute("velocity")
		local position = child:GetAttribute("position")
		local duration = child:GetAttribute("duration")

		root.AssemblyAngularVelocity = Vector3.zero

		if position then
			if typeof(position) == "Vector3" then
				local orientation = root.CFrame - CharacterUtils.GetCFrame(character, true).Position
				character:PivotTo(CFrame.new(position) * orientation)
			else
				character:PivotTo(position)
			end
		end

		root.AssemblyAngularVelocity = Vector3.zero
		local impulse = Instance.new("BodyAngularVelocity")
		impulse:SetAttribute("knockback_mover", true)
		impulse.Name = "@impulse_velocity"
		impulse.MaxTorque = Vector3.new(15000, 15000, 15000) * root.AssemblyMass
		impulse.AngularVelocity = velocity
		impulse.Parent = root

		task.spawn(function()
			task.wait(duration or 1/60)

			--if linear_velocity.Attachment0:GetAttribute("temp") then
			--	linear_velocity.Attachment0:Destroy()
			--end
			impulse:Destroy()
		end)


		Debris:AddItem(child, .1)
	elseif child.Name == "@drag_to_position" then
		local position = child:GetAttribute("position")
		local force = child:GetAttribute("force")
		local duration = child:GetAttribute("duration")
		local allow_walk = child:GetAttribute("allow_walk")
		local force_scale = child:GetAttribute("force_scale") or Vector3.new(1, 0, 1)
		local look_at = child:GetAttribute("look_at")
		local hold = child:GetAttribute("hold")
		local decay = child:GetAttribute("decay")
		local stop_on_obstacle = child:GetAttribute("stop_on_obstacle")

		local difference = position - root.Position 
		local unit = difference.Unit

		local exist = root:FindFirstChild("@drag")
		if exist then
			exist:Destroy()
		end

		local mover = Instance.new("BodyVelocity")
		mover:SetAttribute("knockback_mover", true)
		mover.Name = "@drag"
		mover.MaxForce = (Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * force_scale) * 100000
		mover.Velocity = unit * force
		mover.Parent = root
		Debris:AddItem(mover, duration)

		if look_at and (unit * force).Magnitude > 0 then
			root.CFrame = CFrame.lookAt(root.Position, (root.Position + (unit * force * look_at)) * Vector3.new(1, 0, 1) + Vector3.new(0, root.Position.Y, 0))
		end

		task.spawn(function()
			while mover and mover.Parent do
				local dt = RunService.Heartbeat:Wait()
				--Gizmo.Box:Draw(CFrame.new(position), Vector3.new(.25, .25, .25))

				local difference = (position * force_scale) - (root.Position * force_scale)
				local unit = difference.Magnitude > 0 and difference.Unit or Vector3.zero

				local wall = workspace:Blockcast(root.CFrame - unit, root.Size, unit * force, WorldConstants.world_ray_params)
				if wall and wall.Distance < (stop_on_obstacle and 10 or 5) then
					unit = Vector3.zero

					if stop_on_obstacle then
						if RunService:IsServer() then
							local CharacterController = GlobalFunctions.ProfileHandler:GetProfile(character)
							if not CharacterController then continue end

							--if not live_controller.physics_callback then continue end
							--live_controller.physics_callback.process({
							--	Instance = wall.Instance,
							--	Position = wall.Position,
							--	Normal = wall.Normal,
							--	Material = wall.Material,
							--	Distance = wall.Distance
							--})
						else
							--Net:RemoteEvent("PhysicsReplication"):FireServer({
							--	Instance = wall.Instance,
							--	Position = wall.Position,
							--	Normal = wall.Normal,
							--	Material = wall.Material,
							--	Distance = wall.Distance
							--})
						end

						break
					end
				end

				if difference.Magnitude <= 2 then
					mover.Velocity = Vector3.zero

					if not hold then
						RunService.Heartbeat:Wait()

						break
					end
				else
					mover.Velocity = unit * force
				end

				if allow_walk then
					if humanoid.MoveDirection.Magnitude ~= 0 then
						mover.MaxForce = Vector3.zero
					else
						mover.MaxForce = (Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * force_scale) * 100000
						if look_at and (unit * force).Magnitude > 0 then
							root.CFrame = CFrame.lookAt(root.Position, (root.Position + (unit * force * look_at)) * Vector3.new(1, 0, 1) + Vector3.new(0, root.Position.Y, 0))
						end
					end
				else
					if look_at and (unit * force).Magnitude > 0 then
						root.CFrame = CFrame.lookAt(root.Position, (root.Position + (unit * force * look_at)) * Vector3.new(1, 0, 1) + Vector3.new(0, root.Position.Y, 0))
					end
				end

				if decay then
					local next_value = force * decay
					local difference = force - next_value
					force -= difference * (60 / (1 / dt))
				end
			end

			if mover and mover.Parent then
				mover:Destroy()
			end
		end)

		Debris:AddItem(child, .1)
	elseif child.Name == "@force_walk" then
		local direction = child:GetAttribute("direction")
		local speed = child:GetAttribute("speed")
		local duration = child:GetAttribute("duration")
		local force_scale = child:GetAttribute("force_scale") or Vector3.new(1, 0, 1)
		local decay = child:GetAttribute("decay")
		local start_look_at = child:GetAttribute("start_look_at")
		local allow_rotate_without_shift = if child:GetAttribute("allow_rotate_without_shift") ~= nil then child:GetAttribute("allow_rotate_without_shift") else true

		local exist = root:FindFirstChild("@drag")
		if exist then
			exist:Destroy()
		end

		while root:FindFirstChild("@impulse_velocity") do
			task.wait()
		end

		if start_look_at then
			character:PivotTo(CFrame.lookAt(root.Position, start_look_at * force_scale + Vector3.new(root.Position.X, root.Position.Y, root.Position.Y) * Vector3.new(force_scale.X ~= 0 and 0 or 1, force_scale.Y ~= 0 and 0 or 1, force_scale.Z ~= 0 and 0 or 1)))
		end

		local mover = Instance.new("BodyVelocity")
		mover:SetAttribute("knockback_mover", true)
		mover.Name = "@drag"
		mover.MaxForce = (Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * force_scale) * 100000
		mover.Velocity = CharacterUtils.GetCFrame(character, true)[direction] * speed
		mover.Parent = root
		Debris:AddItem(mover, duration)

		task.spawn(function()
			while mover and mover.Parent do
				local dt = RunService.Heartbeat:Wait()
				if allow_rotate_without_shift or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
					mover.Velocity = CharacterUtils.GetCFrame(character, true)[direction] * speed
				end

				if decay then
					local next_value = speed * decay
					local difference = speed - next_value
					speed -= difference * (60 / (1 / dt))
				end
			end
		end)

		Debris:AddItem(child, .1)
	elseif child.Name == "@look_at" then
		local is_player = Players:GetPlayerFromCharacter(character)
		local behavior = child:GetAttribute("behavior")
		local duration = child:GetAttribute("duration")

		if behavior == "mouse_position_all_axis" then
			local hold_position = child:GetAttribute("hold_position")
			local axis_scale = child:GetAttribute("axis_scale") or Vector3.new(1, 1, 1)
			local visuals = child:GetAttribute("visuals") or nil
			local max_distance = child:GetAttribute("max_distance") or nil
			local Mouse = GlobalFunctions.Mouse;

			--local no_rotate = StatusManager.AddStatus(character, "NoAutoRotate")

			local exist = root:FindFirstChild("@look_at_mover")
			if exist then
				exist:Destroy()
			end

			if hold_position then
				humanoid.PlatformStand = true

				local mover = Instance.new("BodyPosition")
				mover:SetAttribute("knockback_mover", true)
				mover.Name = "@position_holder"
				mover.MaxForce = Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * axis_scale * 100000
				mover.Position = root.Position--CFrame.lookAt(root.Position, Mouse:GetMousePosition{})
				mover.Parent = root
				Debris:AddItem(mover, duration)
			end

			local target_point, result = RunService:IsClient() and Mouse:GetMousePositionAtWorld{} or root.Position + root.CFrame.LookVector * 10, nil
			local mover = Instance.new("BodyGyro")
			mover:SetAttribute("knockback_mover", true)
			mover.Name = "@look_at_mover"
			mover.MaxTorque = Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * 100000
			mover.CFrame = CFrame.lookAt(root.Position, target_point)
			mover.P = 300000
			mover.Parent = root
			Debris:AddItem(mover, duration)

            --[[
			local visual_class
			if visuals and RunService:IsClient() then
				local visual_module = visuals_folder:FindFirstChild(visuals)
				if  visual_module then 
					visual_class = require(visual_module).new(character, mover, child)
				end
			end
            --]]

			while mover and mover.Parent do
				if RunService:IsClient() then
					if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
						target_point, result = workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * axis_scale * (max_distance or 70), nil
					else
						target_point, result = Mouse:GetMousePositionAtWorld{
							max_distance = max_distance,
						}
					end
				else
					target_point, result = root.Position + root.CFrame.LookVector * 10, nil
				end

				if visual_class then
					visual_class:input(target_point, result)
				end

				mover.CFrame = CFrame.lookAt(root.Position, (target_point * axis_scale) + Vector3.new(root.Position.X, root.Position.Y, root.Position.Y) * Vector3.new(axis_scale.X ~= 0 and 0 or 1, axis_scale.Y ~= 0 and 0 or 1, axis_scale.Z ~= 0 and 0 or 1))
				RunService.Heartbeat:Wait()
			end

			no_rotate:Destroy()

			if hold_position then
				humanoid.PlatformStand = false
			end	
		else
			-- TODO: Support for extra behaviors

		end
	end
end

return PhysicsService