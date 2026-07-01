local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationsCache = ReplicatedStorage.Storage.Animations

local AnimatorService = {
	Registry = {} :: {Model: {string: AnimationTrack}},
}

local function GetAnimator(Entity: Model) : Animator
	if Entity:FindFirstChildOfClass("AnimationController") then

		return Entity:FindFirstChildOfClass("AnimationController")
	end

	local Humanoid = Entity:FindFirstChildOfClass("Humanoid")
	local Animator = Humanoid:FindFirstChildOfClass("Animator")

	if not Animator then
		for _, v in Entity:GetDescendants() do
			if v:IsA("Animator") then
				return v
			end
		end
	end

	assert(Animator, "Entity has no animator object.")
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

	for _, Animation in Package:GetDescendants() do
		if Animation:IsA("Animation") then
			Profile[Animation.Name] = Animator:LoadAnimation(Animation)
		end
	end
end

function AnimatorService:LoadAnimation(Entity: Model, Animation: Animation) : AnimationTrack
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(Animation:IsA("Animation"), "Animation has to be a animation.")

	local Profile = self.Registry[Entity] or self:CreateProfile(Entity)
	local Animator = GetAnimator(Entity)

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

function AnimatorService:PlayTrack(Entity: Model, Name: string, Properties: {[string]: number}?) : AnimationTrack
	assert(Entity:IsA("Model"), "Entity has to be a model.")
	assert(typeof(Name) == "string", "Name has to be a string.")

	local Track = self:GetTrack(Entity, Name) 
	Properties = Properties or {}

	local FadeTime = Properties.FadeTime or 0.1
	local Speed = Properties.Speed or 1
	local Weight = Properties.Weight or 1
	local Priority = Properties.Priority or Track.Priority
	local TimePosition = Properties.TimePosition or nil
	local Loop = Properties.Loop or false

	Track.Priority = Priority
	Track.Looped = Loop

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
