local Jloader = require("@game/ReplicatedStorage/JLoader")

local Abilities = require("../Abilities")
local Targets = require("../Targets")
local Types = require("../Types")
local Visuals = require("../Visuals")

type Session = Types.Session
type BiteSpec = Types.BiteSpec

local Bite = {}

local function nextIndex(session: Session, now: number): number
	local state = session.State
	local count = #session.Profile.combo

	if not state.BiteAt or now - state.BiteAt > session.Profile.combo_reset then return 1 end

	return (state.Combo or 0) % count + 1
end

local function land(session: Session, index: number, spec: BiteSpec)
	local root = session.Root
	local look = session:Look()
	local from = root.Position + look * (spec.reach_from or 0)
	local to = root.Position + look * spec.reach
	local victims = Targets.Along(session, from, to, spec.radius)

	if #victims > 0 then
		session.Service.Strike:Fire(index, victims, Jloader.GlobalFunctions.PositionService.Pack(root.CFrame))
	end
end

local function finish(session: Session)
	local state = session.State

	state.Attacking = false
	state.BiteAnimation = nil
	session:Speed()
end

function Bite.Try(session: Session)
	local now = os.clock()
	local state = session.State
	local combo = session.Profile.combo

	if #combo == 0 or Abilities.Held(session) or session:Busy(now) or now < (state.NextBiteAt or 0) or session:Yielded() then return end

	local index = nextIndex(session, now)
	local spec = combo[index]
	local speed = spec.speed or 1
	local swing = spec.windup + spec.recovery

	state.Combo = index
	state.BiteAt = now
	state.BusyUntil = now + swing
	state.NextBiteAt = now + swing + spec.cooldown
	state.Attacking = true
	state.StepIn = spec.step_in or 0
	state.BiteAnimation = spec.animation

	Jloader.GlobalFunctions.StatusService:SetStatus(session.Character, "IsAttacking", true, swing)
	session:Speed()

	if spec.animation then
		session.Animator:Play(spec.animation, speed)
	end

	Visuals.Play(session, "Attack", { ComboIndex = index, Speed = speed })
	session.Service.Swing:Fire(index)

	session:Delay("Bite", spec.windup, function()
		land(session, index, spec)
	end)

	session:Delay("Bite", swing, function()
		finish(session)
	end)
end

function Bite.Began(session: Session)
	session.State.BiteHeld = true
	Bite.Try(session)
end

function Bite.Ended(session: Session)
	session.State.BiteHeld = false
end

function Bite.Step(session: Session)
	if session.State.BiteHeld then
		Bite.Try(session)
	end
end

return Bite
