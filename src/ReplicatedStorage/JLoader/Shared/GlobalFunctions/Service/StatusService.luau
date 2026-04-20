local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Libraries = ReplicatedStorage.Libraries

local StatusService = {
	Registry = {} :: {Model: {[string]: thread}},
}

local function DefaultCheck(Entity: Model, Exclude: {string: any}) : boolean	
	local DefaultChecks = {
		"IsStunned",
		"IsSprinting",
		"IsDashing",
	}

	for ExcludedStatus, _ in Exclude do
		if DefaultChecks[ExcludedStatus] then
			DefaultChecks[ExcludedStatus] = nil
		end
	end
	
	for Status, _ in DefaultChecks do
		if Entity:GetAttribute(Status) then
			return true
		end
	end
	
	return false
end

function StatusService:CreateProfile(Entity : Model) : {}
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	
	if self.Registry[Entity] then
		return self.Registry[Entity]
	end
	
	self.Registry[Entity] = {}
	
	return self.Registry[Entity]
end

function StatusService:RemoveProfile(Entity : Model)
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	if not self.Registry[Entity] then
		return
	end
	
	local Profile = self.Registry[Entity]
	
	for Status: string, Thread: thread in Profile do
		task.cancel(Thread)
		Profile[Status] = nil
	end
	self.Registry[Entity] = nil
end

function StatusService:SetStatus(Entity: Model, Status: string, Value: any, Duration: number?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Status) == "string", "Status has to be a string.")
	
	local Profile = self.Registry[Entity] or self:CreateProfile(Entity)

	if Profile[Status] then
		task.cancel(Profile[Status])
		Profile[Status] = nil
	end
	
	Entity:SetAttribute(Status, Value)
	
	if Duration then
		Profile[Status] = task.delay(Duration, function()
			if Entity.Parent then
				Entity:SetAttribute(Status, nil)
			end
		end)
	end
end

function StatusService:SetStatuses(Entity: Model, Statuses: {{Status: string, Value: any, Duration: number?}})
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Statuses) == "table", "Statuses has to be a table.")

	for Index, Value in Statuses do
		self:SetStatus(Entity, Value.Status, Value.Value, Value.Duration)
	end
end

function StatusService:RemoveStatus(Entity: Model, Status: string)
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Status) == "string", "Status has to be a string.")
	
	local Profile = self.Registry[Entity]

	if not Profile then
		return
	end

	if Profile[Status] then
		task.cancel(Profile[Status])
		Profile[Status] = nil
	end
	
	Entity:SetAttribute(Status, nil)
end

function StatusService:GetStatesTable()
	local StatesLibrary = require(Libraries.StatusLibrary).Types
	
	return StatesLibrary
end

function StatusService:RemoveStatuses(Entity: Model, Statuses: {string})
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Statuses) == "table", "Statuses has to be a table.")
	
	local Profile = self.Registry[Entity]

	if not Profile then
		return
	end
	
	for Status, _ in Statuses do
		if Profile[Status] then
			task.cancel(Profile[Status])
			Profile[Status] = nil
		end

		Entity:SetAttribute(Status, nil)
	end
end

function StatusService:CheckStatuses(Entity: Model, Statuses: {string: any}) : boolean
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Statuses) == "table", "Statuses has to be a table.")
	
	local IsFlagged = true
	
	for State, Value in Statuses do
		if State == "Default" and DefaultCheck(Entity, Statuses) then
			IsFlagged = true
			break
		elseif Entity:GetAttribute(State) ~= (Value or true) then
			IsFlagged = false
			break
		end
	end
	

	return IsFlagged
end

function StatusService:IsAlive(Entity: Model) : boolean
	local Humanoid = Entity:FindFirstChildWhichIsA("Humanoid")

	if not Humanoid then
		return false
	end
	return Humanoid.Health > 0
end

return StatusService