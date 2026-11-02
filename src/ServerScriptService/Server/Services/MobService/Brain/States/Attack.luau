local ATTACKING = "IsAttacking"

local function nextCombo(mob, attack, length: number): number
	local blackboard = mob.Blackboard
	local now = os.clock()

	if not blackboard.LastAttackAt or now - blackboard.LastAttackAt > (attack.combo_reset or 0) then
		blackboard.Combo = 0
	end

	blackboard.Combo = (blackboard.Combo or 0) % length + 1
	blackboard.LastAttackAt = now

	return blackboard.Combo
end

local function face(mob)
	local root = mob:TargetRoot()

	if root then
		mob:Face(root.Position)
	end
end

return {
	Enter = function(mob, data)
		local attack = mob.Config.attack
		local swing = attack.windup + attack.recovery
		local animations = attack.animations

		data.Attack = attack
		data.Duration = swing

		mob.Blackboard.NextAttackAt = os.clock() + swing + attack.cooldown

		if mob.Team then
			mob.Team:NoteAttack(mob)
		end

		mob:Stop()
		face(mob)

		if animations and #animations > 0 then
			data.Animation = animations[nextCombo(mob, attack, #animations)]
			mob.Animation:PlayAction(data.Animation)
		end

		mob.Services.StatusService:SetStatus(mob.Model, ATTACKING, true, swing)
	end,

	Update = function(mob, data, _, elapsed)
		if not data.Hit then
			face(mob)

			if elapsed >= data.Attack.windup then
				data.Hit = true
				mob:Strike(data.Attack)
			end
		end

		if elapsed >= data.Duration then
			data.Done = true
		end
	end,

	Locked = function(_, data)
		return not data.Done
	end,

	Exit = function(mob, data)
		mob:Unface()

		if data.Done then return end

		if data.Animation then
			mob.Animation:Stop(data.Animation)
		end

		mob.Services.StatusService:RemoveStatus(mob.Model, ATTACKING)
	end,
}
