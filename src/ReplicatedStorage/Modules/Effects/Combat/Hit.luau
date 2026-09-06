local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Storage = ReplicatedStorage:WaitForChild("Storage")
local HitEffects = Storage:WaitForChild("Particles"):WaitForChild("CombatVFX"):WaitForChild("Hit")

local Libraries = ReplicatedStorage:WaitForChild("Libraries")
local NPCLibrary = Libraries:WaitForChild("NPCLibrary")

local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local AnimatorService = Jloader.GlobalFunctions.AnimatorService

local Settings = {
	DefaultEffect = "BluntHit", --@ Used when the swing names no effect
	FallbackConfig = "Template", --@ NPCLibrary entry for a victim with none of its own
	Lifetime = 2, --@ Seconds the cloned emitter lingers before Destroy
	ReactionFade = 0.1, --@ Crossfade into the reaction, seconds
	ReactionPriority = Enum.AnimationPriority.Action2,
	Container = "@combat_hit_vfx", --@ Workspace folder the clones are parented under
}

local Hit = {}

local function container()
	local existing = workspace:FindFirstChild(Settings.Container)
	if existing then return existing end

	local folder = Instance.new("Folder")
	folder.Name = Settings.Container
	folder.Parent = workspace
	return folder
end

local function pivotOf(model)
	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function emitAll(root)
	for _, emitter in root:GetDescendants() do
		if not emitter:IsA("ParticleEmitter") then continue end

		local count = emitter:GetAttribute("EmitCount") or 1
		local wait_for = emitter:GetAttribute("EmitDelay") or 0

		if wait_for > 0 then
			task.delay(wait_for, function()
				if emitter.Parent then
					emitter:Emit(count)
				end
			end)
		else
			emitter:Emit(count)
		end
	end
end

local function reactionSet(Info, victim)
	local entry = NPCLibrary:FindFirstChild(victim.Name)
		or NPCLibrary:FindFirstChild(Settings.FallbackConfig)

	if not entry or not entry:IsA("ModuleScript") then return nil end

	local loaded, config = pcall(require, entry)
	if not loaded or typeof(config) ~= "table" then return nil end
	if typeof(config.hit_reaction_path) ~= "string" then return nil end

	return Info.GetPath:ReadPath(config.hit_reaction_path)
end

function Hit.PlayReaction(Info, victim)
	local folder = reactionSet(Info, victim)
	if not folder then return nil end

	local options = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Animation") then
			table.insert(options, child)
		end
	end

	if #options == 0 then return nil end

	--@ Not AnimatorService:LoadAnimation: these are randomised one-shots this function destroys
	--@ itself, and registering them would leave destroyed tracks in the shared Registry.
	local animator = AnimatorService:GetAnimator(victim)
	if not animator then return nil end

	local track = animator:LoadAnimation(options[math.random(#options)])
	track.Priority = Settings.ReactionPriority
	track.Looped = false
	track:Play(Settings.ReactionFade)

	track.Stopped:Once(function()
		track:Destroy()
	end)

	return track
end

function Hit.SpawnParticles(victim, effectName)
	local pivot = pivotOf(victim)
	if not pivot then return nil end

	local template = HitEffects:FindFirstChild(effectName or Settings.DefaultEffect)

	if not template then
		warn(`[Hit] No hit effect named "{tostring(effectName)}" under CombatVFX.Hit.`)
		return nil
	end

	local clone = template:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Massless = true
	clone.CFrame = pivot.CFrame
	clone.Parent = container()

	emitAll(clone)
	Debris:AddItem(clone, Settings.Lifetime)

	return clone
end

function Hit.Emit(Info)
	local victim = Info.Target
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return end
	if not victim.Parent then return end

	Hit.SpawnParticles(victim, Info.Effect)
	Hit.PlayReaction(Info, victim)
end

Hit.Settings = Settings

return Hit
