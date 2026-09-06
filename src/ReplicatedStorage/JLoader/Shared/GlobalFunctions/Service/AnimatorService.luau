local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationsCache = ReplicatedStorage.Storage.Animations

local AnimatorService = {
	Registry = {} :: {Model: {string: AnimationTrack}},
}

--@ Returns the Animator itself, never its parent: an AnimationController was being returned in its
--@ place, which only worked because AnimationController carries a deprecated LoadAnimation.
--@
--@ Returns nil rather than asserting. A rig without an Animator is a real state -- a rig template
--@ authored without one spawns without one -- and throwing took the whole caller down with it.
--@ Use EnsureAnimator on the server to make that state impossible for a given rig.
local _warnedMissing = setmetatable({}, { __mode = "k" })

local function GetAnimator(Entity: Model) : Animator?
	local Host = Entity:FindFirstChildOfClass("Humanoid")
		or Entity:FindFirstChildOfClass("AnimationController")

	--@ Guarded: indexing a nil Humanoid was an error before the descendant sweep below could run,
	--@ so a rig with neither never reached its own fallback.
	local Animator = Host and Host:FindFirstChildOfClass("Animator")

	if not Animator then
		Animator = Entity:FindFirstChildWhichIsA("Animator", true)
	end

	if not Animator and not _warnedMissing[Entity] then
		_warnedMissing[Entity] = true
		warn(`[AnimatorService] "{Entity.Name}" has no Animator, so no track can play on it.`)
	end

	return Animator
end

--@ The one lookup, exposed so callers outside this module report a missing Animator the same way
--@ instead of silently doing nothing.
function AnimatorService:GetAnimator(Entity: Model) : Animator?
	if not Entity then return nil end
	return GetAnimator(Entity)
end

--@ Gives a rig an Animator when its template was authored without one. Server only: an Animator
--@ created on a client exists only there, so tracks the other clients are told to play would have
--@ nothing to play on, and the rig would animate for exactly one player.
function AnimatorService:EnsureAnimator(Entity: Model) : Animator?
	if not Entity then return nil end

	local Existing = Entity:FindFirstChildWhichIsA("Animator", true)
	if Existing then return Existing end

	if not RunService:IsServer() then return nil end

	local Host = Entity:FindFirstChildOfClass("Humanoid")
		or Entity:FindFirstChildOfClass("AnimationController")

	if not Host then return nil end

	local Animator = Instance.new("Animator")
	Animator.Parent = Host

	_warnedMissing[Entity] = nil

	return Animator
end

function AnimatorService:CreateProfile(Entity: Model, AnimationPackage: Folder?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	if self.Registry[Entity] then
		return self.Registry[Entity]
	end

	self.Registry[Entity] = {}

	if AnimationPackage then
		self:LoadPackage(Entity, AnimationPackage)
	end

	return self.Registry[Entity]
end

function AnimatorService:RemoveProfile(Entity: Model)
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	local Profile = self.Registry[Entity]

	if not Profile then return end

	self:DestroyTracks(Entity)
	self.Registry[Entity] = nil
end

function AnimatorService:DestroyTracks(Entity: Model)
	local Profile = self.Registry[Entity]

	if not Profile then return end

	for Name: string, Track: AnimationTrack in Profile do
		Track:Destroy()
		Profile[Name] = nil
	end
end

function AnimatorService:LoadPackage(Entity: Model, Package: Folder)
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(Package:IsA("Folder"), "Package has to be a folder.")

	local Profile = self.Registry[Entity] or self:CreateProfile(Entity)
	local Animator = GetAnimator(Entity)
	if not Animator then return end

	for _, Animation in Package:GetDescendants() do
		if not Animation:IsA("Animation") then continue end

		--@ A placeholder Animation with no asset id throws out of LoadAnimation, which
		--@ would abort the whole package load - and with it everything the caller does
		--@ afterwards (see CharacterProfile.new). Skip it loudly instead.
		if Animation.AnimationId == "" or Animation.AnimationId == "rbxassetid://0" then
			warn(`[AnimatorService] Skipping "{Animation:GetFullName()}" - no AnimationId set.`)
			continue
		end

		local Loaded, Track = pcall(Animator.LoadAnimation, Animator, Animation)

		if not Loaded then
			warn(`[AnimatorService] Failed to load "{Animation:GetFullName()}": {Track}`)
			continue
		end

		Profile[Animation.Name] = Track
	end
end

function AnimatorService:LoadAnimation(Entity: Model, Animation: Animation) : AnimationTrack
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(Animation:IsA("Animation"), "Animation has to be a animation.")

	local Profile = self.Registry[Entity] or self:CreateProfile(Entity)
	local Animator = GetAnimator(Entity)

	if not Animator then return nil end

	local Track = Animator:LoadAnimation(Animation)
	Profile[Animation.Name] = Track

	return Track
end

function AnimatorService:GetTrack(Entity: Model, Name: string) : AnimationTrack
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Name) == "string", "Name has to be a string.")

	local Profile = self.Registry[Entity]

	if Profile and Profile[Name] then
		return Profile[Name]
	else
		local Animation = AnimationsCache:FindFirstChild(Name, true)
		assert(Animation, `Invalid Animation: {Name}`)
		return self:LoadAnimation(Entity, Animation)
	end
end

function AnimatorService:PlayTrack(Entity: Model, Name: string, Properties: {[string]: any}?) : AnimationTrack
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Name) == "string", "Name has to be a string.")

	local Track = self:GetTrack(Entity, Name) 
	Properties = Properties or {}

	local FadeTime = Properties.FadeTime or 0.1
	local Speed = Properties.Speed or 1
	local Weight = Properties.Weight or 1
	local Priority = Properties.Priority or Track.Priority
	local TimePosition = Properties.TimePosition or nil

	Track.Priority = Priority

	if Properties.Loop ~= nil then
		Track.Looped = Properties.Loop
	end

	if TimePosition then
		Track.TimePosition = TimePosition;
	end;


	Track:Play(FadeTime, Weight, Speed)

	return Track
end

function AnimatorService:StopTrack(Entity: Model, Name: string, FadeTime: number?) : AnimationTrack
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Name) == "string", "Name has to be a string.")

	local Track = self:GetTrack(Entity, Name)
	local FadeTime = FadeTime or 0.1

	if not Track then
		local Animator = GetAnimator(Entity)
		if not Animator then return nil end

		for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
			if Track.Name == Name then
				Track:Stop(FadeTime)
				return Track
			end
		end
	end

	Track:Stop(FadeTime)
	return Track
end

function AnimatorService:StopAllAnimations(Entity: Model, FadeTime: number?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	local Animator = GetAnimator(Entity)
	if not Animator then return end

	local Tracks = Animator:GetPlayingAnimationTracks()
	local FadeTime = FadeTime or 0.1

	for _, Track: AnimationTrack in Tracks do
		if not string.find(Track.Name,"Sprint") and not string.find(Track.Name,"Idle") then --@ Ignore Important Animations
			Track:Stop(FadeTime) 
		end
	end
end

function AnimatorService:StopAllWithReference(Entity: Model, Reference: string, FadeTime: number?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	local Animator = GetAnimator(Entity)
	if not Animator then return end

	local Tracks = Animator:GetPlayingAnimationTracks()
	local FadeTime = FadeTime or 0.1

	for _, Track: AnimationTrack in Tracks do
		if Track.Name:match(Reference) then
			Track:Stop(FadeTime)
		end
	end
end

function AnimatorService:GetPlayingAnimation(Entity : Model, Reference : string)
	local Animator = GetAnimator(Entity)
	if not Animator then return end

	local Tracks = Animator:GetPlayingAnimationTracks()

	for _, Track: AnimationTrack in Tracks do
		if Track.Name:match(Reference) then
			return Track
		end
	end
end

function AnimatorService:StopAllWithReferences(Entity: Model, References: {string}, FadeTime: number?)
	assert(Entity:IsA("Model"), "Entity has to be a model.")

	local Animator = GetAnimator(Entity)
	if not Animator then return end

	local Tracks = Animator:GetPlayingAnimationTracks()
	local FadeTime = FadeTime or 0.1

	for _, Track: AnimationTrack in ipairs(Tracks) do
		for _, Reference: string in ipairs(References) do
			if Track.Name:match(Reference) then
				Track:Stop(FadeTime)
			end
		end
	end
end

return AnimatorService
