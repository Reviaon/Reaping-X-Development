local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("./Config")
local Lunge = require("./Lunge")
local Types = require("./Types")

type Session = Types.Session
type Ability = Types.Ability

local Abilities = {}

local GlobalFunctions = Jloader.GlobalFunctions

local ATTACKING = "IsAttacking"

local function specOf(session: Session, name: string): Ability?
	for _, ability in session.Profile.abilities do
		if ability.name == name then
			return ability
		end
	end

	return nil
end

local function readyIn(tool: Tool): number
	local readyAt = tool:GetAttribute(GlobalFunctions.CharacterService.MorphReadyAttribute)
	return if typeof(readyAt) == "number" then readyAt - workspace:GetServerTimeNow() else 0
end

local function capOf(session: Session, name: string): number?
	local caps = session.Entry.leap_distance
	return caps and caps[name]
end

local function finish(session: Session)
	local state = session.State

	Lunge.Release(session)
	state.Attacking = false
	state.Ability = nil
	state.AbilityAnimation = nil
	session:Speed()
end

local function abandon(session: Session)
	local state = session.State

	session:Cancel("Ability")
	Lunge.Stop(session)
	session.Animator:Stop(state.AbilityAnimation)
	state.BusyUntil = nil
	GlobalFunctions.StatusService:RemoveStatus(session.Character, ATTACKING)
	finish(session)
end

local function miss(session: Session, spec: Ability)
	local state = session.State
	local from = state.AbilityAnimation
	local next = spec.miss_animation
	if not from or not next then return end

	session.Animator:Crossfade(from, next, spec.speed, Config.MissFade)
	state.AbilityAnimation = next
end

local function resolve(session: Session, name: unknown, result: unknown)
	local spec = if typeof(name) == "string" then specOf(session, name) else nil
	if not spec or session.State.Ability ~= spec.name then return end

	if result == "Landed" then
		Lunge.Stop(session)
	elseif result == "Missed" then
		Lunge.Release(session)
	end

	if result == "Missed" then
		miss(session, spec)
	elseif result == "Rejected" or result == "Interrupted" then
		abandon(session)
	end
end

local function watch(session: Session, child: Instance)
	if not child:IsA("Tool") or session.Tools[child] then return end

	local name = child:GetAttribute(GlobalFunctions.CharacterService.MorphAbilityAttribute)
	if typeof(name) ~= "string" then return end

	session.Tools[child] = name

	session.Trove:Connect(child.Activated, function()
		Abilities.Try(session, name, child)
	end)

	session.Trove:Connect(child.AncestryChanged, function()
		if not child:IsDescendantOf(game) then
			session.Tools[child] = nil
		end
	end)
end

function Abilities.Try(session: Session, name: string, tool: Tool)
	local spec = specOf(session, name)
	local now = os.clock()
	local state = session.State

	if not spec or session:Busy(now) or session:Yielded() or readyIn(tool) > 0 then return end

	local swing = spec.windup + spec.recovery

	state.BusyUntil = now + swing
	state.NextBiteAt = math.max(state.NextBiteAt or 0, now + swing + spec.cooldown)
	state.Attacking = true
	state.StepIn = 0
	state.Ability = name
	state.AbilityAnimation = spec.animation

	GlobalFunctions.StatusService:SetStatus(session.Character, ATTACKING, true, swing)
	session:Speed()

	if spec.animation then
		session.Animator:Play(spec.animation, spec.speed)
	end

	session.Service.Ability:Fire(name)

	if spec.leap then
		session:Delay("Ability", spec.leap.delay or 0, function()
			if state.Ability == name then
				Lunge.Leap(session, spec, capOf(session, name))
			end
		end)
	end

	session:Delay("Ability", swing, function()
		finish(session)
	end)
end

function Abilities.Start(session: Session)
	local backpack = Players.LocalPlayer:FindFirstChildOfClass("Backpack")

	session.Trove:Connect(session.Service.Ability, function(name: unknown, result: unknown)
		resolve(session, name, result)
	end)

	for _, holder in { backpack, session.Character } do
		if not holder then continue end

		for _, child in holder:GetChildren() do
			watch(session, child)
		end

		session.Trove:Connect(holder.ChildAdded, function(child: Instance)
			watch(session, child)
		end)
	end
end

function Abilities.Held(session: Session): boolean
	local tool = session.Character:FindFirstChildOfClass("Tool")
	return tool ~= nil and session.Tools[tool] ~= nil
end

function Abilities.Step(session: Session)
	for tool, name in session.Tools do
		local spec = specOf(session, name)
		local label = if spec then spec.label else name
		local left = readyIn(tool)
		local text = if left > 0 then `{label} {math.ceil(left)}` else label

		if tool.Name ~= text then
			tool.Name = text
		end
	end
end

return Abilities
