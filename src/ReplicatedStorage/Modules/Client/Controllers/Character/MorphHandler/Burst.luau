local Config = require("./Config")
local Types = require("./Types")

local Burst = {}
Burst.__index = Burst

type Fields = {
	Attachment: Attachment,
	Velocity: LinearVelocity,
	Token: number,
}

type Self = typeof(setmetatable({} :: Fields, Burst))

function Burst.new(session: Types.Session): Types.Burst
	local root = session.Root

	local attachment = Instance.new("Attachment")
	attachment.Name = Config.BurstName
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = Config.BurstName
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(1, 0, 1) * math.max(root.AssemblyMass, 1) * Config.BurstForcePerMass
	velocity.Enabled = false
	velocity.Parent = root

	local self: Fields = { Attachment = attachment, Velocity = velocity, Token = 0 }

	return setmetatable(self, Burst) :: any
end

function Burst.Start(self: Self, velocity: Vector3, duration: number)
	self.Token += 1

	local token = self.Token

	self.Velocity.VectorVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	self.Velocity.Enabled = true

	task.delay(duration, function()
		if self.Token == token then
			Burst.Stop(self)
		end
	end)
end

function Burst.Steer(self: Self, velocity: Vector3)
	if self.Velocity.Enabled then
		self.Velocity.VectorVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
end

function Burst.Stop(self: Self)
	self.Token += 1

	if self.Velocity.Parent then
		self.Velocity.Enabled = false
	end
end

function Burst.Destroy(self: Self)
	Burst.Stop(self)
	self.Velocity:Destroy()
	self.Attachment:Destroy()
end

return Burst
