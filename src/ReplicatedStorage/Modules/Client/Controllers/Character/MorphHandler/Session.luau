local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Abilities = require("./Abilities")
local Animator = require("./Animator")
local Burst = require("./Burst")
local Config = require("./Config")
local Hurt = require("./Hurt")
local Input = require("./Input")
local Landing = require("./Landing")
local Locomotion = require("./Locomotion")
local Properties = require("./Properties")
local Types = require("./Types")

type Session = Types.Session

local Session = {}
Session.__index = Session

local GlobalFunctions = Jloader.GlobalFunctions

local function library(): Instance
	return ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("MorphLibrary")
end

function Session.new(character: Model): Session?
	local CharacterService = GlobalFunctions.CharacterService
	local name: string? = CharacterService.MorphOf(character)
	local module = name and library():FindFirstChild(name)
	local json = character:GetAttribute(CharacterService.MorphProfileAttribute)

	if not name or not module or not module:IsA("ModuleScript") or typeof(json) ~= "string" then return nil end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)

	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then return nil end

	local entry = (require :: any)(module) :: Types.Entry
	local profile = HttpService:JSONDecode(json) :: Types.Profile

	local self = setmetatable({
		Name = name,
		Entry = entry,
		Profile = profile,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Service = Jloader.GetService("MorphService"),
		Trove = GlobalFunctions.Trove.new(),
		State = { ClearAt = {}, Jump = Properties.Fresh() },
		Threads = {},
		Stepping = {},
		Tools = {},
		WalkSpeed = entry.walk_speed or profile.walk_speed,
		RunSpeed = entry.run_speed or profile.run_speed,
		JumpPower = entry.jump or 0,
		Destroyed = false,
	}, Session) :: any

	local session = self :: Session

	session.Animator = Animator.new(session)
	session.Burst = Burst.new(session)

	return session
end

function Session.Start(self: Session)
	local humanoid = self.Humanoid

	for _, state in Config.DisabledStates do
		humanoid:SetStateEnabled(state, false)
	end

	humanoid.UseJumpPower = true

	self:Speed()

	self.Trove:Connect(self.Character.AttributeChanged, function()
		if self:Yielded() then
			self:Interrupt()
		end

		self:Speed()
	end)

	self.Trove:Connect(self.Character.AncestryChanged, function()
		if not self.Character:IsDescendantOf(game) then
			self:Destroy()
		end
	end)

	self.Trove:Connect(humanoid.Died, function()
		self:Halt()
	end)

	self.Trove:Connect(RunService.Heartbeat, function()
		if humanoid.Health <= 0 then return end

		Locomotion.Step(self)
		Input.Step(self)
		Abilities.Step(self)
	end)

	Properties.Start(self)
	Landing.Start(self)
	Hurt.Start(self)
	Input.Bind(self)
	Abilities.Start(self)
end

function Session.Speed(self: Session)
	if not self.Destroyed then
		Properties.Apply(self)
	end
end

function Session.Yielded(self: Session): boolean
	local StatusService = GlobalFunctions.StatusService
	local character = self.Character

	return StatusService:IsHitYielded(character) or StatusService:IsActionLocked(character) or StatusService:CheckStatuses(character, Config.YieldStatuses)
end

function Session.Busy(self: Session, now: number): boolean
	return now < (self.State.BusyUntil or 0)
end

function Session.Look(self: Session): Vector3
	local look = self.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
end

function Session.Delay(self: Session, group: string, seconds: number, callback: () -> ())
	local threads = self.Threads[group] or {}
	self.Threads[group] = threads

	local thread: thread

	thread = task.delay(math.max(seconds, 0), function()
		local index = table.find(threads, thread)

		if index then
			table.remove(threads, index)
		end

		if not self.Destroyed then
			callback()
		end
	end)

	table.insert(threads, thread)
end

function Session.Cancel(self: Session, group: string)
	local threads: { thread } = self.Threads[group] or {}

	for _, thread in threads do
		pcall(task.cancel, thread)
	end

	self.Threads[group] = nil
end

function Session.Interrupt(self: Session)
	local state = self.State

	self:Cancel("Bite")
	self:Cancel("Ability")
	self.Burst:Stop()
	Abilities.Release(self)

	for _, key in { state.BiteAnimation, state.DashAnimation, state.AbilityAnimation } do
		self.Animator:Stop(key)
	end

	if state.Attacking then
		GlobalFunctions.StatusService:RemoveStatus(self.Character, "IsAttacking")
	end

	state.Attacking = false
	state.BiteAnimation = nil
	state.DashAnimation = nil
	state.Dash = nil
	state.Ability = nil
	state.AbilityAnimation = nil
	state.BusyUntil = nil
end

function Session.Halt(self: Session)
	self:Interrupt()
	self.State.BiteHeld = false
	self.State.Running = false
	self.Animator:StopAll(Config.DeathFade)
end

function Session.Destroy(self: Session)
	if self.Destroyed then return end

	self.Destroyed = true

	for group in self.Threads do
		self:Cancel(group)
	end

	self.Trove:Destroy()
	self.Burst:Destroy()
	self.Animator:Destroy()
end

return Session
