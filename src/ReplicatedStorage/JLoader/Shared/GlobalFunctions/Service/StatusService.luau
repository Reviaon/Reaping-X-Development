local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatusLibrary = require(ReplicatedStorage.Libraries.CharacterLibrary.StatusLibrary)
local StatusResolver = require(script.Parent.StatusResolver)

local StatusService = {
	Registry = {},
	Settings = {
		ExpirySuffix = "_Expires", --@ Attribute holding a status's server-time expiry
	},
}
local Handle = {}
Handle.__index = Handle

local DEFAULT_SOURCE = {}
local NextId = 0

local function Now()
	return workspace:GetServerTimeNow()
end

local function ValidateEntity(Entity)
	assert(typeof(Entity) == "Instance" and Entity:IsA("Model"), "Expected a character Model")
end

local function ValidateName(Name)
	assert(typeof(Name) == "string" and Name ~= "", "Expected a non-empty status name")
end

local function ValidateDuration(Duration)
	assert(Duration == nil or (typeof(Duration) == "number" and Duration >= 0 and Duration < math.huge), "Expected a finite, non-negative duration")
end

local function Invalidate(Entry)
	if Entry.Thread then
		task.cancel(Entry.Thread)
		Entry.Thread = nil
	end
	Entry.Entity = nil
end

local function Publish(Entity, Name, Entries)
	local Newest, Latest
	for _, Entry in Entries or {} do
		if not Newest or Entry.Id > Newest.Id then
			Newest = Entry
		end
		Latest = math.max(Latest or 0, Entry.ExpiresAt)
	end
	local Value
	if Newest then
		Value = Newest.Value
	end
	if Entity:GetAttribute(Name) ~= Value then
		Entity:SetAttribute(Name, Value)
	end

	--@ Server time, so every machine can count down a status another machine applied.
	local Expires = Latest and Latest < math.huge and Latest or nil
	if Entity:GetAttribute(Name .. StatusService.Settings.ExpirySuffix) ~= Expires then
		Entity:SetAttribute(Name .. StatusService.Settings.ExpirySuffix, Expires)
	end
end

function Handle:GetRemainingTime()
	if not self.Entity then return 0 end
	return math.max(0, self.ExpiresAt - Now())
end

function Handle:Destroy()
	local Entity = self.Entity
	if not Entity then return end
	local Profile = StatusService.Registry[Entity]
	local Entries = Profile and Profile.Statuses[self.Status]
	if not Entries or Entries[self.Key] ~= self then return end

	Entries[self.Key] = nil
	Invalidate(self)
	if next(Entries) == nil then
		Profile.Statuses[self.Status] = nil
	end
	Publish(Entity, self.Status, Entries)
end

Handle.Remove = Handle.Destroy

function StatusService:CreateProfile(Entity)
	ValidateEntity(Entity)
	local Existing = self.Registry[Entity]
	if Existing then return Existing end

	local Profile = { Statuses = {}, Connections = {} }
	self.Registry[Entity] = Profile
	local function Cleanup()
		if self.Registry[Entity] == Profile then
			self:RemoveProfile(Entity)
		end
	end
	table.insert(Profile.Connections, Entity.Destroying:Connect(Cleanup))
	table.insert(Profile.Connections, Entity.AncestryChanged:Connect(function(_, Parent)
		if Parent == nil then
			Cleanup()
		end
	end))

	local function BindHumanoid(Child)
		if Child:IsA("Humanoid") then
			table.insert(Profile.Connections, Child.Died:Connect(Cleanup))
		end
	end
	local Humanoid = Entity:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		BindHumanoid(Humanoid)
	end
	table.insert(Profile.Connections, Entity.ChildAdded:Connect(BindHumanoid))
	return Profile
end

function StatusService:RemoveProfile(Entity)
	ValidateEntity(Entity)
	local Profile = self.Registry[Entity]
	if not Profile then return end
	self.Registry[Entity] = nil

	for _, Connection in Profile.Connections do
		Connection:Disconnect()
	end
	for Name, Entries in Profile.Statuses do
		for _, Entry in Entries do
			Invalidate(Entry)
		end
		Publish(Entity, Name, nil)
	end
	table.clear(Profile.Statuses)
	table.clear(Profile.Connections)
end

local function Apply(Entity, Name, Value, Duration, Key, Source, Extend)
	ValidateEntity(Entity)
	ValidateName(Name)
	ValidateDuration(Duration)
	local Kind = typeof(Value)
	assert(Kind == "boolean" or Kind == "string" or (Kind == "number" and Value == Value and math.abs(Value) < math.huge), "Expected a boolean, string, or finite number")
	if Duration == 0 then
		if Extend then
			StatusService:RemoveStatus(Entity, Name, Source or DEFAULT_SOURCE)
		end
		return nil
	end

	local Profile = StatusService:CreateProfile(Entity)
	local Entries = Profile.Statuses[Name]
	if not Entries then
		Entries = {}
		Profile.Statuses[Name] = Entries
	end

	local ExpiresAt = Duration and Now() + Duration or math.huge
	local Previous = Entries[Key]
	if Previous then
		if Extend and Previous.Value == Value then
			ExpiresAt = math.max(ExpiresAt, Previous.ExpiresAt)
		end
		Invalidate(Previous)
	end

	NextId += 1
	local Entry = setmetatable({
		Entity = Entity,
		Status = Name,
		Source = Source,
		Key = Key,
		Value = Value,
		Id = NextId,
		ExpiresAt = ExpiresAt,
	}, Handle)
	Entries[Key] = Entry

	if ExpiresAt < math.huge then
		Entry.Thread = task.delay(math.max(0, ExpiresAt - Now()), function()
			Entry.Thread = nil
			Entry:Destroy()
		end)
	end
	Publish(Entity, Name, Entries)
	return Entry
end

function StatusService:ApplyStatus(Entity, Name, Value, Duration)
	return Apply(Entity, Name, Value, Duration, {}, nil, false)
end

function StatusService:SetStatus(Entity, Name, Value, Duration, Source)
	if Source ~= nil then
		ValidateName(Source)
	end
	if Value == nil then
		self:RemoveStatus(Entity, Name, Source)
		return nil
	end
	return Apply(Entity, Name, Value, Duration, Source or DEFAULT_SOURCE, Source, true)
end

function StatusService:SetStatuses(Entity, Statuses)
	ValidateEntity(Entity)
	assert(typeof(Statuses) == "table", "Expected status entries")
	local Handles = {}
	for _, Entry in ipairs(Statuses) do
		Handles[#Handles + 1] = self:SetStatus(Entity, Entry.Status, Entry.Value, Entry.Duration, Entry.Source)
	end
	return Handles
end

function StatusService:RemoveStatus(Entity, Name, Source)
	ValidateEntity(Entity)
	ValidateName(Name)
	if Source ~= nil and Source ~= DEFAULT_SOURCE then
		ValidateName(Source)
	end
	local Profile = self.Registry[Entity]
	local Entries = Profile and Profile.Statuses[Name]

	if Source ~= nil then
		local Entry = Entries and Entries[Source]
		if Entry then
			Entry:Destroy()
		end
		return
	end

	if Entries then
		Profile.Statuses[Name] = nil
		for _, Entry in Entries do
			Invalidate(Entry)
		end
	end
	Publish(Entity, Name, nil)
end

function StatusService:RemoveSource(Entity, Source)
	ValidateEntity(Entity)
	ValidateName(Source)
	local Profile = self.Registry[Entity]
	if not Profile then return end
	local Handles = {}
	for _, Entries in Profile.Statuses do
		if Entries[Source] then
			table.insert(Handles, Entries[Source])
		end
	end
	for _, Entry in Handles do
		Entry:Destroy()
	end
end

function StatusService:RemoveStatuses(Entity, Statuses)
	ValidateEntity(Entity)
	assert(typeof(Statuses) == "table", "Expected status names")
	for Key, Value in Statuses do
		self:RemoveStatus(Entity, typeof(Key) == "number" and Value or Key)
	end
end

function StatusService:GetStatesTable()
	return StatusLibrary.Types
end

function StatusService:CheckStatuses(Entity, Statuses)
	ValidateEntity(Entity)
	assert(typeof(Statuses) == "table", "Expected status checks")
	for Key, Value in Statuses do
		if typeof(Key) == "number" then
			ValidateName(Value)
			if Entity:GetAttribute(Value) == true then return true end
		elseif Key ~= "Default" then
			if Entity:GetAttribute(Key) == Value then return true end
		end
	end
	if Statuses.Default == true then
		for _, Name in StatusLibrary.DefaultChecks do
			if Statuses[Name] == nil and Entity:GetAttribute(Name) == true then return true end
		end
	end
	return false
end

function StatusService:ResolveProperties(Entity, Defaults)
	ValidateEntity(Entity)
	return StatusResolver.Resolve(Entity:GetAttributes(), StatusLibrary.Types, Defaults, StatusLibrary.PropertyModes)
end

function StatusService:GetDominantStatus(Entity)
	ValidateEntity(Entity)
	local Selected, Priority = nil, -math.huge
	for Name, Value in Entity:GetAttributes() do
		local Definition = StatusLibrary.Types[Name]
		if Value == true and Definition then
			local Rank = Definition.Priority or 0
			if Rank > Priority or (Rank == Priority and (not Selected or Name < Selected)) then
				Selected, Priority = Name, Rank
			end
		end
	end
	return Selected
end

function StatusService:IsHitImmune(Entity)
	if typeof(Entity) ~= "Instance" or not Entity:IsA("Model") then return false end
	return self:CheckStatuses(Entity, StatusLibrary.HitImmune)
end

function StatusService:GetRemainingTime(Entity, Name)
	ValidateEntity(Entity)
	ValidateName(Name)
	local Expires = Entity:GetAttribute(Name .. StatusService.Settings.ExpirySuffix)
	if typeof(Expires) ~= "number" then return nil end
	return math.max(0, Expires - Now())
end

function StatusService:IsAlive(Entity)
	ValidateEntity(Entity)
	local Humanoid = Entity:FindFirstChildOfClass("Humanoid")
	return Humanoid ~= nil and Humanoid.Health > 0
end

return StatusService
