local Jloader = require("@game/ReplicatedStorage/JLoader")
local GlobalFunctions = Jloader.GlobalFunctions

local Animation = require("./Animation")
local Combat = require("./Combat")
local Motion = require("./Motion")
local Perception = require("./Perception")
local Rig = require("./Rig")
local Spacing = require("./Spacing")
local StateMachine = require("./Brain/StateMachine")
local Tree = require("./Brain/Tree")

local Mob = {}
Mob.__index = Mob

local DISABLING = { IsStunned = true, InPairScene = true, IsRagdolled = true }
local HELD = { InPairScene = true, IsRagdolled = true }
local LAUNCH_STUN_ATTRIBUTE = "LaunchStun"

local random = Random.new()

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Mob.new(kind, model: Model, home: Vector3)
	local now = os.clock()
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	local self = setmetatable({
		Kind = kind,
		Name = kind.Name,
		Config = kind.Config,
		Tree = kind.Tree,
		Model = model,
		Humanoid = humanoid,
		Root = model.PrimaryPart,
		Home = home,
		Services = GlobalFunctions,
		Trove = GlobalFunctions.Trove.new(),
		Blackboard = {},
		Memory = {},
		Target = nil,
		Team = nil,
		Moving = false,
		Stopping = false,
		Halted = false,
		Speed = 0,
		DesiredSpeed = 0,
		FacePoint = nil,
		Destination = nil,
		WrittenHeading = nil,
		Nudging = false,
		Separation = Vector3.zero,
		Crowd = nil,
		Tier = nil,
		LastThinkAt = now,
		NextThinkAt = now + random:NextNumber(0, 0.25),
		LastHealth = humanoid.Health,
		Dead = false,
		Destroyed = false,
	}, Mob)

	self.Facing = Rig.Facing(self.Root)
	self.Body = Rig.Body(model)

	if self.Facing then
		self.Facing.CFrame = self.Root.CFrame.Rotation
		self.Facing.Enabled = true
	end

	if self.Config.launch_stun then
		model:SetAttribute(LAUNCH_STUN_ATTRIBUTE, self.Config.launch_stun)
	end

	self.Machine = StateMachine.new(self)
	self.Animation = self.Trove:Add(Animation.new(self))
	self.Died = self.Trove:Add(GlobalFunctions.Signal.new())
	self.Destroying = self.Trove:Add(GlobalFunctions.Signal.new())

	self.Trove:Connect(humanoid.Died, function()
		self:Die()
	end)

	self.Trove:Connect(humanoid.HealthChanged, function(health)
		local reactions = self.Config.hurt_animations

		if health < self.LastHealth and health > 0 then
			if reactions and #reactions > 0 and not self:IsArmored() then
				self.Animation:PlayAction(reactions[random:NextInteger(1, #reactions)])
			end

			if not self:Provoker() then
				local nearest = Perception.NearestPlayer(self.Root.Position, self:Setting("lose_range"))

				if nearest then
					self:Provoke(nearest)
				end
			end
		end

		self.LastHealth = health
	end)

	self.Trove:Connect(model.AncestryChanged, function()
		if not model:IsDescendantOf(game) then
			self:Destroy()
		end
	end)

	return self
end

function Mob:Setting(key: string | number): any
	if typeof(key) == "number" then return key end

	local value = self.Config[key]

	if value == nil then
		error(`[MobService] {self.Name} has no "{tostring(key)}" in its MobLibrary entry.`, 2)
	end

	return value
end

function Mob:GetTarget(): Model?
	if self.Target and not Perception.IsValidTarget(self.Target) then
		self.Target = nil
	end

	return self.Target
end

function Mob:SetTarget(target: Model?)
	if target ~= self.Target and self.Team then
		self.Team:ReleaseSlot(self)
	end

	if target and not self.Target then
		self.Blackboard.AggroAt = os.clock()
	end

	self.Target = target
end

function Mob:Provoke(attacker: Model)
	if self.Dead or not Perception.IsValidTarget(attacker) then return end

	local blackboard = self.Blackboard

	blackboard.Provoker = attacker
	blackboard.ProvokedUntil = os.clock() + (self.Config.provoke_time or 0)
	blackboard.Returning = false
end

function Mob:Provoker(): Model?
	local blackboard = self.Blackboard
	local provoker = blackboard.Provoker

	if provoker and os.clock() < (blackboard.ProvokedUntil or 0) and Perception.IsValidTarget(provoker) then
		return provoker
	end

	blackboard.Provoker = nil

	return nil
end

function Mob:TargetRoot(): BasePart?
	return Perception.RootOf(self:GetTarget())
end

function Mob:TargetDistance(): number?
	local root = self:TargetRoot()
	return root and (root.Position - self.Root.Position).Magnitude
end

function Mob:LeadPoint(seconds: number): Vector3
	local root = self:TargetRoot()
	if not root then return self.Root.Position end

	local velocity = root.AssemblyLinearVelocity

	return root.Position + Vector3.new(velocity.X, 0, velocity.Z) * seconds
end

function Mob:EngagePoint(target: Vector3, distance: number?): Vector3
	local config = self.Config
	local offset = target - self.Root.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)

	if planar.Magnitude <= 1e-3 then return target end

	local engage = distance or config.engage_distance or config.attack.reach

	return target - planar.Unit * math.min(engage, planar.Magnitude)
end

function Mob:Burst(speed: number, unbraked: number?)
	self.Speed = math.max(self.Speed, speed)

	if unbraked then
		self.FreeUntil = os.clock() + unbraked
	end
end

function Mob:DistanceTo(position: Vector3): number
	return flat(position - self.Root.Position).Magnitude
end

function Mob:HomeDistance(): number
	return self:DistanceTo(self.Home)
end

function Mob:IsArmored(): boolean
	local machine = self.Machine
	return machine ~= nil and machine.State ~= nil and machine.State.Armored == true and not machine:IsDone()
end

function Mob:IsDisabled(): boolean
	if self.Humanoid.Health <= 0 then return true end

	local armored = self:IsArmored()

	if GlobalFunctions.StatusService:CheckStatuses(self.Model, if armored then HELD else DISABLING) then return true end
	if armored then return false end

	local recipe = GlobalFunctions.KnockbackService.Active(self.Model)

	return recipe ~= nil and not recipe.steer
end

function Mob:MoveTo(position: Vector3, speedKey: string | number)
	local properties = GlobalFunctions.StatusService:ResolveProperties(self.Model, { WalkSpeed = self:Setting(speedKey) })

	local destination = position + Spacing.Steer(self.Separation)

	self.Moving = true
	self.Stopping = false
	self.Nudging = false
	self.Destination = destination
	self.DesiredSpeed = math.max(0, properties.WalkSpeed)
	self.Humanoid:MoveTo(destination)
end

function Mob:Stop()
	if not self.Moving then return end

	self.DesiredSpeed = 0
	self.Stopping = true
end

function Mob:Halt()
	self.Halted = true
	self.Moving = false
	self.Stopping = false
	self.DesiredSpeed = 0
	self.Speed = 0
	self.FacePoint = nil
	self.Destination = nil
	self.Humanoid.WalkSpeed = 0
	self.Humanoid:MoveTo(self.Root.Position)

	if self.Facing then
		self.Facing.Enabled = false
	end
end

function Mob:Resume()
	if not self.Halted then return end

	self.Halted = false

	if self.Facing then
		self.WrittenHeading = nil
		self.Facing.CFrame = self.Root.CFrame.Rotation
		self.Facing.Enabled = true
	end
end

function Mob:Face(position: Vector3)
	self.FacePoint = position
end

function Mob:Unface()
	self.FacePoint = nil
end

function Mob:KeepSpace()
	if self.Halted then return end

	local crowded = self.Separation.Magnitude > Spacing.Settings.NudgeThreshold

	if crowded and (not self.Moving or self.Stopping or self.Nudging) then
		self:MoveTo(self.Root.Position, "walk_speed")
		self.Nudging = true
	elseif self.Nudging and not crowded then
		self.Nudging = false
		self:Stop()
	end
end

function Mob:Step(dt: number)
	if self.Dead then return end

	Motion.Step(self, dt)
end

function Mob:LeaveTeam()
	local team = self.Team
	if not team then return end

	self.Team = nil
	team:Leave(self)
end

function Mob:Strike(attack): number
	return Combat.Strike(self, attack)
end

function Mob:Think(dt: number)
	if self.Dead then return end

	self.Separation = if self.Crowd then Spacing.Push(self, self.Crowd) else Vector3.zero

	Tree.Tick(self.Tree, self, dt)
	self.Machine:Update(dt)
	self:KeepSpace()
	self.Animation:UpdateLocomotion()
end

function Mob:Die()
	if self.Dead then return end

	self.Dead = true
	self.Machine:Exit()
	self:Halt()
	self:LeaveTeam()
	self.Animation:StopAll()
	self.Died:Fire(self)

	self.Trove:Add(task.delay(self.Config.corpse_time or 0, function()
		self:Destroy()
	end))
end

function Mob:Destroy()
	if self.Destroyed then return end

	local model = self.Model
	local services = GlobalFunctions

	self.Destroyed = true
	self.Dead = true
	self.Machine:Exit()
	self:LeaveTeam()
	self.Destroying:Fire(self)

	services.ServerController:ClearCharacter(model)
	services.AnimatorService:RemoveProfile(model)
	services.CooldownService:RemoveProfile(model)
	services.StatusService:RemoveProfile(model)

	self.Trove:Destroy()

	if model.Parent then
		model:Destroy()
	end

	self.Target = nil
	table.clear(self.Blackboard)
	table.clear(self.Memory)
end

return Mob
