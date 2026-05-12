-- @ Start
local PhysicsService = {}

-- @ Services
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

function PhysicsService.ApplyImpulse(controller : {}, settings : {})
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local impulseChild = Instance.new("Folder")
	impulseChild.Name = "@apply_impulse"
	impulseChild:SetAttribute("velocity", settings.velocity)
	impulseChild:SetAttribute("duration", settings.duration or 0.5)
	impulseChild:SetAttribute("force_scale", settings.force_scale or Vector3.new(1, 0, 1))
	impulseChild:SetAttribute("angular_scale", settings.angular_scale or 0)
	impulseChild:SetAttribute("stop_on_obstacle", settings.stop_on_obstacle ~= false)
	impulseChild:SetAttribute("obstacle_check_duration", settings.obstacle_check_duration or 1)
	impulseChild:SetAttribute("obstacle_speed_quota", settings.obstacle_speed_quota or 10)
	impulseChild:SetAttribute("force_update_velocity", settings.force_update_velocity or false)
	impulseChild:SetAttribute("velocity_fadeoff", settings.velocity_fadeoff or false)
	impulseChild:SetAttribute("fadeoff_duration", settings.fadeoff_duration or 0.3)
	impulseChild:SetAttribute("fadeoff_delay", settings.fadeoff_delay or 0)
	impulseChild:SetAttribute("fadeoff_easing_style", settings.fadeoff_easing_style or Enum.EasingStyle.Linear)
	impulseChild:SetAttribute("fadeoff_easing_direction", settings.fadeoff_easing_direction or Enum.EasingDirection.Out)
	impulseChild:SetAttribute("velocity_direction", settings.velocity_direction or settings.velocity.Unit)
	impulseChild.Parent = root

	PhysicsService.ProcessPhysics(character, impulseChild)
end

function PhysicsService.ProcessPhysics(character: Model, child: Instance)
	local root: BasePart = character:FindFirstChild("HumanoidRootPart")
	local humanoid: Humanoid = character:FindFirstChild("Humanoid")

	if child.Name == "@apply_impulse" then
		local exist_mover = root:FindFirstChild("@impulse_velocity")

		if exist_mover then
			exist_mover:Destroy()
		end

		warn("Processing Impulse for", character.Name, "with velocity", child:GetAttribute("velocity"))

		local velocity = child:GetAttribute("velocity")
		local duration = child:GetAttribute("duration") or 0.5
		local force_scale = child:GetAttribute("force_scale") or Vector3.new(1, 1, 1)
		local angular_scale = child:GetAttribute("angular_scale") or 0
		local stop_on_obstacle = child:GetAttribute("stop_on_obstacle")
		local obstacle_speed_quota = child:GetAttribute("obstacle_speed_quota") or 10
		local obstacle_check_duration = child:GetAttribute("obstacle_check_duration") or 2

		local force_update_velocity = child:GetAttribute("force_update_velocity") or false
		local velocity_direction = child:GetAttribute("velocity_direction") or velocity.Unit

		local velocity_fadeoff = child:GetAttribute("velocity_fadeoff") or false
		local fadeoff_duration = child:GetAttribute("fadeoff_duration") or 0.3
		local fadeoff_delay = child:GetAttribute("fadeoff_delay") or 0
		local fadeoff_easing_style = child:GetAttribute("fadeoff_easing_style") or Enum.EasingStyle.Linear
		local fadeoff_easing_direction = child:GetAttribute("fadeoff_easing_direction") or Enum.EasingDirection.Out

		local velocity_speed = velocity.Magnitude

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
		linear_velocity.MaxForce = Vector3.new(root.AssemblyMass, root.AssemblyMass, root.AssemblyMass) * force_scale * 4e4
		linear_velocity.Velocity = velocity
		linear_velocity.Parent = root

		local impulse_end_time = tick() + duration

		if force_update_velocity then
			task.spawn(function()
				while linear_velocity and linear_velocity.Parent and tick() < impulse_end_time do
					linear_velocity.Velocity = velocity_direction * velocity_speed
					RunService.Heartbeat:Wait()
				end
			end)
		end

		if velocity_fadeoff then
			task.spawn(function()
				task.wait(fadeoff_delay)

				local speedMultiplier = Instance.new("NumberValue")
				speedMultiplier.Value = 1

				local tweenInfo = TweenInfo.new(fadeoff_duration, fadeoff_easing_style, fadeoff_easing_direction)
				local tween = TweenService:Create(speedMultiplier, tweenInfo, {Value = 0})

				speedMultiplier.Changed:Connect(function()
					if linear_velocity and linear_velocity.Parent then
						linear_velocity.Velocity = velocity * speedMultiplier.Value
					end
				end)

				tween:Play()
				tween.Completed:Connect(function()
					if linear_velocity and linear_velocity.Parent then
						linear_velocity:Destroy()
					end
				end)


			end)
		else
			task.spawn(function()
				task.wait(duration)
				if linear_velocity and linear_velocity.Parent then
					linear_velocity:Destroy()
				end
			end)
		end

		if stop_on_obstacle then
			local end_time = os.clock() + obstacle_check_duration

			task.spawn(function()
				while os.clock() <= end_time do
					RunService.Heartbeat:Wait()

					local current_velocity = root.AssemblyLinearVelocity
					if current_velocity.Magnitude < obstacle_speed_quota then continue end

					local Params = RaycastParams.new()
					Params.FilterType = Enum.RaycastFilterType.Exclude
					Params.FilterDescendantsInstances = {character}
					Params.IgnoreWater = true
					Params.RespectCanCollide = true

					local wall = workspace:Blockcast(root.CFrame - current_velocity.Unit, root.Size, current_velocity, Params)

					if wall and wall.Distance <= 15 then
						if linear_velocity and linear_velocity.Parent then
							linear_velocity:Destroy()
						end
						break
					end
				end
			end)
		end

		Debris:AddItem(child, duration + fadeoff_delay + fadeoff_duration + 0.1)
	end
end

return PhysicsService