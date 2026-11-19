local StealthConfig = require("../../../StealthService/Config")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local Memory = require("./Memory")

local Stealth = {}

local function settingsOf(mob): MobTypes.Sneak?
	return mob.Config.sneak or nil
end

function Stealth.Sneaking(target: Model): boolean
	return target:GetAttribute(StealthConfig.Attribute) == true
end

function Stealth.Alerted(mob, target: Model): boolean
	local sneak = settingsOf(mob)
	local entry = Memory.Peek(mob, target)

	return sneak ~= nil and entry ~= nil and entry.AlertedAt ~= nil and os.clock() - entry.AlertedAt <= sneak.forget
end

function Stealth.Alert(mob, target: Model)
	Memory.Entry(mob, target).AlertedAt = os.clock()
end

function Stealth.Hides(mob, target: Model): boolean
	if not settingsOf(mob) or mob.Target == target or not Stealth.Sneaking(target) then return false end

	return not Stealth.Alerted(mob, target)
end

function Stealth.Reach(mob): number
	local sneak = settingsOf(mob)
	return if sneak then sneak.notice else 0
end

return Stealth
