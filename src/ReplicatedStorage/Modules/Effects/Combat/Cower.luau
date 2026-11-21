--[[@
	**Cower**: a player caught by a mob's cry covers up until the stun ends
	- **Owner only:** only the stunned player's own client plays the clips; the Animator replicates them to everyone
	- **Clips:** `Info.Start` once, then `Info.Loop` looped, at `Settings.Priority`; both stop at `Info.Until` (server time)
	  - The hand-off is timed off the start clip's own length, not its `Stopped`: a start that hadn't loaded yet, or that something else stopped, used to drop straight to the loop
	  - A start stopped early is picked up again where it should be
	- **Facing:** while it cowers the player turns toward `Info.Source` (the crying mob) at `Settings.TurnSpeed`
	- **Again:** a second cry while still cowering restarts the clips and moves the end
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local AnimatorService = Jloader.GlobalFunctions.AnimatorService

local Settings = {
	Priority = Enum.AnimationPriority.Action4,
	Fade = 0.15,
	EndFade = 0.3,
	TurnSpeed = math.rad(540), --@ Radians per second the player turns toward the crying mob
	LoadWait = 1, --@ Seconds a start clip that hasn't loaded yet is waited for, then played from the top, before the loop takes over
}

local Cower = {}

local active = setmetatable({}, { __mode = "k" })

local function face(character: Model, source: any, dt: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	local from = typeof(source) == "Instance" and source:IsA("Model") and source.PrimaryPart
	if not root or not root:IsA("BasePart") or not from then return end

	local flat = (from.Position - root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1e-3 then return end

	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local current = math.atan2(-look.X, -look.Z)
	local goal = math.atan2(-flat.X, -flat.Z)
	local turn = (goal - current + math.pi) % (2 * math.pi) - math.pi
	local step = math.clamp(turn, -Settings.TurnSpeed * dt, Settings.TurnSpeed * dt)

	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, current + step, 0)
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

	for _, playing in { entry.Start, entry.Loop } do
		if playing and playing.IsPlaying then
			playing:Stop(fade)
		end
	end
end

function Cower.Play(Info)
	if typeof(Info.Character) ~= "Instance" or Info.Character ~= Players.LocalPlayer.Character then return end

	local character = Info.Character :: Model
	if typeof(Info.Until) ~= "number" then return end

	local remaining = Info.Until - workspace:GetServerTimeNow()
	if remaining <= 0 then return end

	local previous = active[character]

	if previous then
		finish(previous, Settings.Fade)
	end

	local entry = { Start = track(character, Info.Start), Loop = track(character, Info.Loop) }
	active[character] = entry

	entry.Turn = RunService.PreRender:Connect(function(dt)
		face(character, Info.Source, dt)
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
			local began = os.clock()

			while active[character] == entry and start.Length <= 0 and os.clock() - began < Settings.LoadWait do
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

	task.delay(remaining, function()
		if active[character] ~= entry then return end

		active[character] = nil
		finish(entry, Settings.EndFade)
	end)
end

Cower.Settings = Settings

return Cower
