local Perception = require("../Senses/Perception")
local Sight = require("../Senses/Sight")

local Targets = {}

function Targets.State()
	return { Targets = {} }
end

Targets.Methods = {}

function Targets.Methods:Holds(target: Model, range: number, except): boolean
	local root = Perception.RootOf(target)
	if not root then return false end

	for member in self.Members do
		if member == except or member.Dead or not member.Root then continue end

		if (member.Root.Position - root.Position).Magnitude <= range and Sight.Knows(member, target) then
			return true
		end
	end

	return false
end

function Targets.Methods:Share(target: Model)
	if Perception.IsValidTarget(target) then
		self.Targets[target] = true
	end
end

function Targets.Methods:Drop(target: Model)
	self.Targets[target] = nil
end

function Targets.Methods:Prune(range: number)
	for target in self.Targets do
		if not Perception.IsValidTarget(target) or not self:Holds(target, range) then
			self.Targets[target] = nil
		end
	end
end

return Targets
