local Dodge = {}

local STUN = "IsStunned"
local HELD = { "IsRagdolled", "InPairScene" }

local random = Random.new()

local function aimedAt(mob, dodge, origin: CFrame): boolean
	local offset = mob.Root.Position - origin.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)

	if planar.Magnitude > dodge.range then return false end
	if planar.Magnitude < 1e-3 then return true end

	local look = Vector3.new(origin.LookVector.X, 0, origin.LookVector.Z)
	if look.Magnitude < 1e-3 then return true end

	return look.Unit:Dot(planar.Unit) >= math.cos(math.rad(dodge.arc / 2))
end

local function escapable(mob): boolean
	local model = mob.Model

	if model:GetAttribute(STUN) ~= true or mob.Humanoid.Health <= 0 then return false end

	for _, status in HELD do
		if model:GetAttribute(status) == true then return false end
	end

	return true
end

function Dodge.React(mobs, attacker: Model, combatService)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end

	local now = os.clock()

	for mob in mobs do
		local dash = mob.Config.dash
		local dodge = dash and dash.dodge

		if not dodge or mob.Dead or not mob.Root or not mob:GetTarget() then continue end

		local blackboard = mob.Blackboard

		if now < (blackboard.DodgeReadyAt or 0) then continue end

		local disabled = mob:IsDisabled()
		local chance = dodge.chance

		if disabled then
			if not dodge.escape or not escapable(mob) then continue end
			chance = dodge.escape
		elseif mob.Machine:IsLocked() then
			continue
		end

		if not aimedAt(mob, dodge, root.CFrame) then continue end

		if random:NextNumber() > chance then
			blackboard.DodgeReadyAt = now + (dodge.retry or 0)
			continue
		end

		blackboard.DodgeReadyAt = now + dodge.cooldown

		if disabled then
			mob.Services.StatusService:RemoveStatus(mob.Model, STUN)
			combatService:CancelKnockback(mob.Model)
		end

		mob.Machine:Request("Dash", { from = root.Position }, disabled)
	end
end

return Dodge
