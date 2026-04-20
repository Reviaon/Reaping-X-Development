local Suffix = "_Timer"

local CooldownService = {
	Registry = {} :: {Model: {[string]: thread}},
}

function CooldownService:CreateProfile(Entity : Model) : {[string]: thread}
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	if self.Registry[Entity] then
		return self.Registry[Entity]
	end

	self.Registry[Entity] = {}

	return self.Registry[Entity]
end

function CooldownService:RemoveProfile(Entity : Model)
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

function CooldownService:ApplyCooldown(Entity: Model, Cooldown: string, Duration: number?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldown) == "string", "Cooldown has to be a string.")

	local Profile = self.Registry[Entity] or self:CreateProfile(Entity)
	
	if Profile[Cooldown] then
		task.cancel(Profile[Cooldown])
		Profile[Cooldown] = nil
	end
	
	Entity:SetAttribute(
		Cooldown.. Suffix, 
		string.format("S:{%s} D:{%s}", workspace:GetServerTimeNow(), Duration or "")
	)

	if Duration then
		Profile[Cooldown] = task.delay(Duration, function()
			if Entity.Parent then
				Entity:SetAttribute(Cooldown.. Suffix, nil)
			end
		end)
	end
end

function CooldownService:ApplyCooldowns(Entity: Model, Cooldowns: {{Cooldown: string, Duration: number?}})
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldowns) == "table", "Cooldowns has to be a table.")

	for Index, Value in Cooldowns do
		self:AddCooldown(Entity, Value.Cooldown, Value.Duration)
	end
end

function CooldownService:RemoveCooldown(Entity: Model, Cooldown: string)
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldown) == "string", "Cooldown has to be a string.")

	local Profile = self.Registry[Entity]

	if not Profile then
		return
	end

	if Profile[Cooldown] then
		task.cancel(Profile[Cooldown])
		Profile[Cooldown] = nil
	end

	Entity:SetAttribute(Cooldown.. Suffix, nil)
end

function CooldownService:RemoveCooldowns(Entity: Model, Cooldowns: {string})
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldowns) == "table", "Cooldowns has to be a table.")

	local Profile = self.Registry[Entity]

	if not Profile then
		return
	end

	for Cooldown, _ in Cooldowns do
		if Profile[Cooldown] then
			task.cancel(Profile[Cooldown])
			Profile[Cooldown] = nil
		end

		Entity:SetAttribute(Cooldown.. Suffix, nil)
	end
end

function CooldownService:CheckCooldown(Entity: Model, Cooldown: string) : boolean
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldown) == "string", "Cooldown has to be a string.")
	
	if not Entity:GetAttribute(Cooldown.. Suffix) then
		return false
	end
	return true
end

function CooldownService:CheckCooldowns(Entity: Model, Cooldowns: {string}) : boolean
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldowns) == "table", "Cooldowns has to be a table.")
	
	local IsFlagged = false
	
	for Cooldown, _ in Cooldowns do
		if self:CheckCooldown(Entity, Cooldown) then
			IsFlagged = true
			break
		end
	end
	return IsFlagged
end

function CooldownService:GetRemainingTime(Entity: Model, Cooldown: string, Decimals: string?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Cooldown) == "string", "Cooldown has to be a string.")
	
	Decimals = Decimals or "2"
	
	if not Entity:GetAttribute(Cooldown.. Suffix) then
		return 0
	end
	
	local Attribute = Entity:GetAttribute(Cooldown.. Suffix)
	local Start, Duration = Attribute:match("S:{(%d+%.?%d*)} D:{(%d+)}")
	
	if not Duration then
		return "inf"
	end

	local CurrentTime = workspace:GetServerTimeNow()
	local RemainingTime = Start + Duration - CurrentTime
	
	if RemainingTime <= 0 then
		return 0
	end
	return tonumber(string.format(`%.{Decimals}f`, RemainingTime)) :: number
end

return CooldownService