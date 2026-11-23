--[[@
	**Gesture**: a player answers a mob with a gesture of their own (the reply to a MockingJay's bow)
	- **Owner only:** only the gesturing player's own client plays the clips; the Animator replicates them to everyone
	- **Clips:** `Info.Start` once, then `Info.Loop` looped, at `Settings.Priority`; both stop at `Info.Until` (server time)
	  - The hand-off is timed off the start clip's own length, not its `Stopped`: a start that hadn't loaded yet, or that something else stopped, used to drop straight to the loop
	  - A start stopped early is picked up again where it should be
	- **Facing:** while it lasts the player turns to look along `Info.Look` at `Settings.TurnSpeed`, or toward `Info.Source` (the mob) when there is none
	- **Placement:** `Info.Stand` is where the clips line up with the mob; the player slides there at `Settings.SeatSpeed`
	- **Over shift lock:** it holds `NoRotate` (source `Settings.FacingSource`), so the camera doesn't turn the player back while it lasts
	- **Free to go:** the player isn't held; moving, once `Settings.MoveGrace` has passed, ends it early
	- **Again:** a second gesture while one is playing restarts the clips and moves the end
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local AnimatorService = Jloader.GlobalFunctions.AnimatorService
local StatusService = Jloader.GlobalFunctions.StatusService

local FLAT = Vector3.new(1, 0, 1)
local NO_ROTATE = "NoRotate"

local Settings = {
	Priority = Enum.AnimationPriority.Action4,
	Fade = 0.15,
	EndFade = 0.3,
	TurnSpeed = math.rad(540), --@ Radians per second the player turns toward the mob
	LoadWait = 1, --@ Seconds a start clip that hasn't loaded yet is waited for, then played from the top, before the loop takes over
	MoveGrace = 0.35, --@ Seconds before moving ends it, so the keys held walking up don't cancel it at once
	SeatSpeed = 10, --@ Studs per second the player slides to `Info.Stand`
	FacingSource = "Gesture", --@ NoRotate source held while it lasts, so shift lock leaves the facing alone
}

local Gesture = {}

local active = setmetatable({}, { __mode = "k" })

local function seat(position: Vector3, stand: any, dt: number): Vector3
	if typeof(stand) ~= "Vector3" then return position end

	local gap = (stand - position) * FLAT
	if gap.Magnitude < 1e-3 then return position end

	return position + gap.Unit * math.min(gap.Magnitude, Settings.SeatSpeed * dt)
end

local function heading(position: Vector3, info): Vector3?
	if typeof(info.Look) == "Vector3" then return info.Look * FLAT end

	local source = info.Source
	local from = typeof(source) == "Instance" and source:IsA("Model") and source.PrimaryPart

	return if from then (from.Position - position) * FLAT else nil
end

local function place(character: Model, info, dt: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end

	local position = seat(root.Position, info.Stand, dt)
	local look = root.CFrame.LookVector * FLAT
	local current = math.atan2(-look.X, -look.Z)
	local flat = heading(position, info)
	local yaw = current

	if flat and flat.Magnitude >= 1e-3 then
		local goal = math.atan2(-flat.X, -flat.Z)
		local turn = (goal - current + math.pi) % (2 * math.pi) - math.pi

		yaw = current + math.clamp(turn, -Settings.TurnSpeed * dt, Settings.TurnSpeed * dt)
	end

	root.CFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

local function moving(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0
end

local function track(character: Model, name: any): AnimationTrack?
	if typeof(name) ~= "string" or not AnimatorService:HasAnimation(name) then return nil end

	local loaded, found = pcall(AnimatorService.GetTrack, AnimatorService, character, name)
	return if loaded then found else nil
end

local function finish(entry, fade: number)
	if entry.Turn then
		entry.Turn:Disconnect()
	end

	StatusService:RemoveStatus(entry.Character, NO_ROTATE, Settings.FacingSource)

	for _, playing in { entry.Start, entry.Loop } do
		if playing and playing.IsPlaying then
			playing:Stop(fade)
		end
	end
end

function Gesture.Play(Info)
	if typeof(Info.Character) ~= "Instance" or Info.Character ~= Players.LocalPlayer.Character then return end

	local character = Info.Character :: Model
	if typeof(Info.Until) ~= "number" then return end

	local remaining = Info.Until - workspace:GetServerTimeNow()
	if remaining <= 0 then return end

	local previous = active[character]

	if previous then
		finish(previous, Settings.Fade)
	end

	local entry = { Character = character, Start = track(character, Info.Start), Loop = track(character, Info.Loop) }
	local began = os.clock()

	active[character] = entry
	StatusService:SetStatus(character, NO_ROTATE, true, nil, Settings.FacingSource)

	local function stop()
		if active[character] ~= entry then return end

		active[character] = nil
		finish(entry, Settings.EndFade)
	end

	entry.Turn = RunService.PreRender:Connect(function(dt)
		if os.clock() - began >= Settings.MoveGrace and moving(character) then
			stop()
			return
		end

		place(character, Info, dt)
	end)

	local function loop()
		if active[character] ~= entry or not entry.Loop then return end

		entry.Loop.Priority = Settings.Priority
		entry.Loop.Looped = true
		entry.Loop:Play(Settings.Fade)
	end

	local start = entry.Start

	if start then
		start.Priority = Settings.Priority
		start.Looped = false
		start:Play(Settings.Fade)

		task.spawn(function()
			local waited = os.clock()

			while active[character] == entry and start.Length <= 0 and os.clock() - waited < Settings.LoadWait do
				task.wait()
			end

			local length = start.Length
			local from = os.clock() - (if start.IsPlaying then start.TimePosition else 0)

			while active[character] == entry and length > 0 do
				local at = os.clock() - from
				if at >= length - Settings.Fade then break end

				if not start.IsPlaying then
					start:Play(0)
					start.TimePosition = at
				end

				task.wait()
			end

			loop()
		end)
	else
		loop()
	end

	task.delay(remaining, stop)
end

Gesture.Settings = Settings

return Gesture
