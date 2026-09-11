local StatusService = require(script.Parent.StatusService)
local CooldownService = { Registry = setmetatable({}, { __mode = "k" }) }
local SUFFIX = "_Timer"

local function AttributeName(Name)
	assert(typeof(Name) == "string" and Name ~= "", "Expected a non-empty cooldown name")
	return Name .. SUFFIX
end

local function Remaining(Entity, Name)
	local Value = Entity:GetAttribute(AttributeName(Name))
	if Value == nil then return 0 end
	if typeof(Value) ~= "string" then return 0 end
	local StartText, DurationText = Value:match("^S:{([^}]+)} D:{([^}]*)}$")
	local Start = tonumber(StartText)
	if not Start or Start ~= Start or math.abs(Start) == math.huge then return 0 end
	if DurationText == "" then return math.huge end
	local Duration = tonumber(DurationText)
	if not Duration or Duration ~= Duration or Duration < 0 or Duration == math.huge then return 0 end
	return math.max(0, Start + Duration - workspace:GetServerTimeNow())
end

function CooldownService:CreateProfile(Entity)
	assert(typeof(Entity) == "Instance" and Entity:IsA("Model"), "Expected a character Model")
	local Profile = self.Registry[Entity]
	if not Profile then
		Profile = {}
		self.Registry[Entity] = Profile
	end
	return Profile
end

function CooldownService:RemoveProfile(Entity)
	local Profile = self.Registry[Entity]
	if not Profile then return end
	self.Registry[Entity] = nil
	for Name in Profile do
		StatusService:RemoveStatus(Entity, AttributeName(Name))
	end
end

function CooldownService:ApplyCooldown(Entity, Name, Duration)
	assert(Duration == nil or (typeof(Duration) == "number" and Duration >= 0 and Duration < math.huge), "Expected a finite, non-negative duration")
	local Key = AttributeName(Name)
	local Profile = self:CreateProfile(Entity)
	Profile[Name] = true
	if Duration == 0 then
		self:RemoveCooldown(Entity, Name)
		return nil
	end
	local Payload = string.format("S:{%.17g} D:{%s}", workspace:GetServerTimeNow(), Duration and string.format("%.17g", Duration) or "")
	return StatusService:SetStatus(Entity, Key, Payload, Duration)
end

function CooldownService:ApplyCooldowns(Entity, Cooldowns)
	assert(typeof(Cooldowns) == "table", "Expected cooldown entries")
	for _, Entry in ipairs(Cooldowns) do
		self:ApplyCooldown(Entity, Entry.Cooldown, Entry.Duration)
	end
end

function CooldownService:RemoveCooldown(Entity, Name)
	StatusService:RemoveStatus(Entity, AttributeName(Name))
	local Profile = self.Registry[Entity]
	if Profile then
		Profile[Name] = nil
	end
end

function CooldownService:RemoveCooldowns(Entity, Cooldowns)
	assert(typeof(Cooldowns) == "table", "Expected cooldown names")
	for Key, Value in Cooldowns do
		self:RemoveCooldown(Entity, typeof(Key) == "number" and Value or Key)
	end
end

function CooldownService:CheckCooldown(Entity, Name)
	return Remaining(Entity, Name) > 0
end

function CooldownService:CheckCooldowns(Entity, Cooldowns)
	assert(typeof(Cooldowns) == "table", "Expected cooldown names")
	for Key, Value in Cooldowns do
		if self:CheckCooldown(Entity, typeof(Key) == "number" and Value or Key) then return true end
	end
	return false
end

function CooldownService:GetRemainingTime(Entity, Name, Decimals)
	local Value = Remaining(Entity, Name)
	if Value == math.huge then return Value end
	local Precision = Decimals == nil and 2 or tonumber(Decimals)
	assert(Precision and Precision % 1 == 0 and Precision >= 0 and Precision <= 10, "Expected precision from 0 to 10")
	return tonumber(string.format("%." .. Precision .. "f", Value))
end

return CooldownService
