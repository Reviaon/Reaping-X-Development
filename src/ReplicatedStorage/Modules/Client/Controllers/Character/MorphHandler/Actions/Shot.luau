local Config = require("../Config")
local Types = require("../Types")
local Visuals = require("../Visuals")

type Session = Types.Session
type Hold = Types.Hold

local Shot = {}

local function hold(session: Session, spec: Hold, on: boolean)
	if session.Destroyed then return end

	session.Character:SetAttribute(spec.attribute, if on then true else nil)
	session.Service.Hold:Fire(spec.attribute, on)

	if on then
		Visuals.Shot(session, spec.visual)
	end
end

local function holdBetween(session: Session, spec: Hold, from: string, track: AnimationTrack)
	local open = false
	local connections: { RBXScriptConnection } = {}

	local function close()
		for _, connection in connections do
			connection:Disconnect()
		end

		if open then
			open = false
			hold(session, spec, false)
		end
	end

	table.insert(connections, track:GetMarkerReachedSignal(from):Connect(function()
		if open then return end

		open = true
		hold(session, spec, true)
	end))

	table.insert(connections, track:GetMarkerReachedSignal(spec.to or from):Connect(function()
		if open then
			close()
		end
	end))

	table.insert(connections, track.Stopped:Connect(close))

	for _, connection in connections do
		session.Trove:Add(connection)
	end
end

local function holdThrough(session: Session, spec: Hold, track: AnimationTrack, speed: number)
	local length = if track.Length > 0 then track.Length else Config.HoldFallback

	hold(session, spec, true)
	session:Delay("Shot", length / speed, function()
		hold(session, spec, false)
	end)
end

function Shot.Began(session: Session, index: number?)
	local shots = session.Entry.shots
	local shot = if shots and index then shots[index] else nil

	if not shot or session:Yielded() then return end

	local speed = shot.speed or 1
	local track = session.Animator:Play(shot.animation, speed)

	Visuals.Shot(session, shot.visual, speed)

	local spec = shot.hold
	if not spec or not track then return end

	if spec.from then
		holdBetween(session, spec, spec.from, track)
	else
		holdThrough(session, spec, track, speed)
	end
end

return Shot
