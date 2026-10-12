local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Storage = ReplicatedStorage:WaitForChild("Storage")
local HitEffects = Storage:WaitForChild("Particles"):WaitForChild("CombatVFX"):WaitForChild("Hit")

local Libraries = ReplicatedStorage:WaitForChild("Libraries")
local NPCLibrary = Libraries:WaitForChild("NPCLibrary")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local AnimatorService = Jloader.GlobalFunctions.AnimatorService
local EffectService = Jloader.GlobalFunctions.EffectService

local Settings = {
	DefaultEffect = "BluntHit", --@ Used when the swing names no effect
	FallbackConfig = "Template", --@ NPCLibrary entry for a victim with none of its own
	Lifetime = 2, --@ Seconds the cloned emitter lingers before Destroy
	ReactionFade = 0.1, --@ Crossfade into the reaction, seconds
	ReactionPriority = Enum.AnimationPriority.Action2,
	Container = "@combat_hit_vfx", --@ Workspace folder the clones are parented under

	--@ Storage.Other.HitHighlight is put on the victim as authored, its FillTransparency eased to
	--@ HighlightEnd over HighlightTime seconds, then removed. 1 fades it out; 0 fills it in
	--@ ShakeLibrary shapes for the local player landing a hit and taking one
	ShakeDealt = "HitDealt",
	ShakeTaken = "HitTaken",

	HighlightTime = 0.35,
	HighlightEnd = 1,
}

local Hit = {}

local highlights = setmetatable({}, { __mode = "k" })

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

	local effect = EffectService.new({ Effect = template })
	effect:SetCFrame(pivot.CFrame)
	effect:SetParent(container())
	effect:Play()
	effect:SetRemoval(Settings.Lifetime)

	return effect
end

--@ Only the two people in the hit feel it: the one struck, and the one who landed it.
function Hit.Shake(victim, attacker)
	local player = game:GetService("Players").LocalPlayer
	local character = player and player.Character
	if not character then return end

	local shape = (victim == character and Settings.ShakeTaken) or (attacker == character and Settings.ShakeDealt)
	if not shape then return end

	local camera = Jloader.GetHandler("CameraHandler")

	if camera and camera.Shake then
		camera:Shake(shape)
	end
end

function Hit.Highlight(victim)
	local other = Storage:FindFirstChild("Other")
	local template = other and other:FindFirstChild("HitHighlight")
	if not template then return nil end

	local existing = highlights[victim]

	if existing then
		existing:Destroy()
	end

	local highlight = template:Clone()
	highlight.Adornee = victim
	highlight.Parent = victim

	highlights[victim] = highlight

	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(Settings.HighlightTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = Settings.HighlightEnd }
	)

	tween.Completed:Once(function()
		if highlights[victim] == highlight then
			highlights[victim] = nil
		end

		highlight:Destroy()
	end)

	tween:Play()

	return highlight
end

function Hit.Emit(Info)
	local victim = Info.Target
	if typeof(victim) ~= "Instance" or not victim:IsA("Model") then return end
	if not victim.Parent then return end

	Hit.Shake(victim, Info.Attacker)
	Hit.Highlight(victim)
	Hit.SpawnParticles(victim, Info.Effect)
	Hit.PlayReaction(Info, victim)
end

Hit.Settings = Settings

return Hit
