--@ Start
local EffectService = {}
EffectService.__index = EffectService

--@ Statis Utility
EffectService.Util = {}

--@ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--@ Shared Functions
local World = workspace:WaitForChild("World")
local Visuals = World:WaitForChild("Visuals")

--@ Imports
local TableUtil = require(script.Parent.TableUtil)
type Config = {[string]: any}

local HiddenTransparencyCache = setmetatable({}, {__mode = "k"})

--@ The weld that carries the effect on its host, and the welds that hold the effect's
--@ own geometry together. Named apart so either set can be found or cleared alone.
local HOST_WELD_NAME = "@EffectWeld"
local SELF_WELD_NAME = "@EffectSelfWeld"

--@ Template
local Template = {
	Effect  = nil,
	EmitDivider = 1, 
	CurrentScale = 1,
	OriginalScale= {},
}

--@ Classes that ARE the visual rather than a container for one. An asset can be one of these
--@ directly (e.g. a bare Trail): it then has NO descendants and no transform of its own, so every
--@ traversal must include the ROOT - walking GetDescendants() alone silently does nothing for it.
local VISUAL_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
}

local function IsVisualInstance(object: Instance?): boolean
	return object ~= nil and VISUAL_CLASSES[object.ClassName] == true
end

--@ Root + descendants, so a bare Trail/Beam/ParticleEmitter asset is processed like any other.
local function GetEffectObjects(root: Instance?): {Instance}
	if not root then
		return {}
	end

	local objects = root:GetDescendants()
	table.insert(objects, root)

	return objects
end

--@ Matches an instance, its name, or its parent's name against a black/whitelist. Parent is nil
--@ for a freshly cloned root, so it must be guarded - indexing it was a crash for root visuals.
local function MatchesList(list: {any}?, object: Instance): boolean
	if not list then
		return false
	end

	if table.find(list, object) or table.find(list, object.Name) then
		return true
	end

	local parent = object.Parent

	return parent ~= nil and table.find(list, parent.Name) ~= nil
end

local function GetStudioCFrame(obj)
	if obj:IsA("Model") then
		return obj:GetPivot()

	elseif obj:IsA("BasePart") or obj:IsA("MeshPart") then
		return obj.CFrame

	elseif obj:IsA("Attachment") then
		return obj.WorldCFrame

	elseif obj:IsA("Trail") or obj:IsA("Beam") then
		--@ Drawn BETWEEN attachments, so they carry no transform. Anchor off Attachment0 when
		--@ present so a DummyRoot offset still resolves; identity otherwise.
		local anchor = obj.Attachment0

		return anchor and anchor.WorldCFrame or CFrame.identity

	elseif obj:IsA("ParticleEmitter") then
		local host = obj.Parent

		if host and host:IsA("BasePart") then
			return host.CFrame
		elseif host and host:IsA("Attachment") then
			return host.WorldCFrame
		end

		return CFrame.identity

	else
		warn("EffectService: Could not determine Studio CFrame for:", obj.ClassName)
		return CFrame.identity
	end
end

local function GetTransparencyTargets(root: Instance): {Instance}
	local targets = {root}

	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(targets, descendant)
	end

	return targets
end

local function CanAdjustTransparency(object: Instance): boolean
	return object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture")
end

local function GetOriginalTransparency(cache, object: Instance)
	local cachedTransparency = cache and cache[object]
	if cachedTransparency ~= nil then
		return cachedTransparency
	end

	return object.Transparency
end

function EffectService.new(config, cached_vfx)
	config = TableUtil.Reconcile(config, Template)

	local effectTemplate = config.Effect

	if not config.Effect then
		warn("@EffectService: No Effect provided in config", config)
	end

	local effectCF = GetStudioCFrame(effectTemplate)

	--@ Did user include a DummyRoot in the asset?
	--@ Plop & Play Effects, Create Model with dummy root @ positon of rig.
	local dummyRoot = effectTemplate.Parent:FindFirstChild("DummyRoot")
	local relativeOffset = CFrame.identity

	if dummyRoot and dummyRoot:IsA("BasePart") then

		local dummyCF = dummyRoot.CFrame
		relativeOffset = dummyCF:ToObjectSpace(effectCF)
	end

	local effect_ = effectTemplate:Clone()

	if cached_vfx then
		table.insert(cached_vfx, effect_)
	end

	local selfObject = setmetatable({
		Effect = effect_,
		Owner = config.Owner,
		EmitDivider = config.EmitDivider,

		Cancellable = config.Cancellable,
		CancellableCallback = config.CancelBack,
		CancellableWhitelist = config.CancellableWhitelist,
		CancelWindow = config.CancelWindow or 1,
		CancelFade = config.CancelFade or true,

		_Offset = relativeOffset, 
	}, EffectService)

	selfObject:_BindCancellable()

	return selfObject
end

function EffectService:_BindCancellable()
	if not self.Cancellable then
		return
	end

	if not self.Owner then
		return
	end

	local character = self.Owner.Character 
	if not character then
		return
	end

	if not self.CancellableWhitelist or #self.CancellableWhitelist == 0 then
		return
	end

	self._cancelConnections = {}
	self._isCancelled = false

	self._cancelExpireTime = os.clock() + (self.CancelWindow or 1)

	if os.clock() > self._cancelExpireTime then
		self:_CleanupCancellable()
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		local deathConnection
		deathConnection = humanoid.Died:Connect(function()
			if self._isCancelled then return end
			if os.clock() > self._cancelExpireTime then return end

			self._isCancelled = true

			if self.CancelFade then
				if self.Effect then
					self:FadeOutAll(0.1, {})
				end
			else
				self:Destroy()
			end

			if typeof(self.CancellableCallback) == "function" then
				pcall(self.CancellableCallback, self, "Died")
			end

			self:_CleanupCancellable()
		end)

		table.insert(self._cancelConnections, deathConnection)
	end

	for _, attributeName in ipairs(self.CancellableWhitelist) do
		local connection

		connection = character:GetAttributeChangedSignal(attributeName):Connect(function()
			if self._isCancelled then
				return
			end

			if os.clock() > self._cancelExpireTime then
				return
			end

			local value = character:GetAttribute(attributeName)
			if not value then
				return
			end

			self._isCancelled = true

			if self.CancelFade then
				if self.Effect then
					self:FadeOutAll(0.1,{})
				end
			else
				self:Destroy()
			end

			if typeof(self.CancellableCallback) == "function" then
				pcall(self.CancellableCallback, self, attributeName)
			end

			self:_CleanupCancellable()
		end)

		table.insert(self._cancelConnections, connection)
	end

end

function EffectService:_CleanupCancellable()
	if not self._cancelConnections then return end

	for _, connection in ipairs(self._cancelConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	self._cancelConnections = nil
end

--@ Binds every BasePart in an effect to its root; the assets ship unanchored and would
--@ otherwise drift off it, dragging the mesh-VFX Start/End markers away. Constraints go on
--@ the ROOT, never inside the part they bind - ForgeVFX reparents a marker's children onto a
--@ pooled part, so a constraint inside one chains it into the character assembly and flings the player.
local function WeldToRoot(root: BasePart, effect: Instance): number
	local bound = 0
	local alreadyBound = {}

	for _, existing in root:GetChildren() do
		if existing:IsA("WeldConstraint") and existing.Name == SELF_WELD_NAME then
			alreadyBound[existing.Part1] = true
		end
	end

	for _, descendant in effect:GetDescendants() do
		if not descendant:IsA("BasePart") or descendant == root or alreadyBound[descendant] then
			continue
		end

		local weldconstraint = Instance.new("WeldConstraint")
		weldconstraint.Name = SELF_WELD_NAME
		weldconstraint.Part0 = root
		weldconstraint.Part1 = descendant
		weldconstraint.Parent = root

		alreadyBound[descendant] = true
		bound += 1
	end

	return bound
end

function EffectService:Weld(Part : {Any})
	if not self.Effect then return end

	--@ Resolve something weldable: a Model welds by its PrimaryPart, and a bare
	--@ Trail/Beam/ParticleEmitter has no geometry at all, so it welds by the part it is
	--@ parented to. Assigning a non-BasePart to Part0 is an error, hence the guard.
	local part0 = self.Effect

	if part0:IsA("Model") then
		part0 = part0.PrimaryPart
	elseif not part0:IsA("BasePart") then
		local host = part0.Parent
		part0 = (host and host:IsA("BasePart")) and host or nil
	end

	if not part0 then
		return
	end

	--@ Runs before the early return below so an effect is made rigid even when there is
	--@ nothing to carry it: holding its own geometry together is its own concern.
	WeldToRoot(part0, self.Effect)

	if part0 == Part then
		return
	end

	local weldconstraint = Instance.new("WeldConstraint")
	weldconstraint.Part0 = part0

	weldconstraint.Part1 = Part
	weldconstraint.Name = HOST_WELD_NAME
	weldconstraint.Parent = part0

	return weldconstraint
end

function EffectService:SetColor(Color : Color3, Whitelist : {string}?)
	if not self.Effect then 
		return 
	end

	Whitelist = Whitelist or {}

	for _, obj in GetEffectObjects(self.Effect) do
		--@ Trails/Beams take a ColorSequence exactly like an emitter does.
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
			obj.Color = ColorSequence.new(Color)
		elseif obj:IsA("PointLight") then
			obj.Color = Color
		end
	end
end
--@ Utility Methods
local cachedAnimationById: { [string]: Animation } = {}

function EffectService.Util.Toggle(effect: Instance, Toggle : boolean, whitelist)
	if not effect then return false end

	whitelist = whitelist or {}

	--@ Root INCLUDED so a bare Trail / Beam / emitter asset toggles like a nested one. An empty
	--@ whitelist means EVERY visual, matching Util.Play (it previously matched nothing).
	for _, Object in GetEffectObjects(effect) do
		if IsVisualInstance(Object) and (#whitelist == 0 or MatchesList(whitelist, Object)) then
			Object.Enabled = if Toggle ~= nil then Toggle else not Object.Enabled
		end
	end

	return true
end

function EffectService.Util.Play(effect: Instance, emitDivider: number, whitelist)
	if not effect then return false end

	local objects = effect:GetDescendants()
	table.insert(objects, effect)

	whitelist = whitelist or {}
	emitDivider = emitDivider or 1


	for _, obj in ipairs(objects) do
		--@ Streaks play by being enabled for EmitDuration, not by emitting a count.
		if obj:IsA("Trail") or obj:IsA("Beam") then
			local allowed = #whitelist == 0 or MatchesList(whitelist, obj)

			if allowed then
				obj.Enabled = true

				local streakDuration = obj:GetAttribute("EmitDuration") or 0
				if streakDuration > 0 then
					task.delay(streakDuration, function()
						if obj and obj.Parent then
							obj.Enabled = false
						end
					end)
				end
			end
		end

		if obj:IsA("PointLight") then
			obj.Enabled = true

			local FadeTime = obj:GetAttribute("FadeTime") or 1

			TweenService:Create(obj, TweenInfo.new(FadeTime), {
				Range = 0
			}):Play()
		end

		if obj:IsA("ParticleEmitter") then
			local count = obj:GetAttribute("EmitCount") or 1
			local repeatN = obj:GetAttribute("EmitRepeat") or 1
			local delay = obj:GetAttribute("EmitDelay") or 0
			local duration = obj:GetAttribute("EmitDuration") or 0

			local allowed =
				table.find(whitelist, obj)
				or table.find(whitelist, obj.Name)
				or table.find(whitelist, obj.Parent.Name)

			if not whitelist or #whitelist == 0 then
				allowed = true
			end

			if not allowed then
				continue
			end

			if duration > 0 then
				obj.Enabled = true

				task.delay(duration, function()
					if obj then
						obj.Enabled = false
					end
				end)
			else
				local function doEmit()
					for _ = 1, repeatN do
						obj:Emit(math.ceil(count / emitDivider))
						task.wait(delay)
					end
				end

				if delay > 0 then
					task.delay(delay, doEmit)
				else
					doEmit()
				end
			end
		end
	end
	return true
end

function EffectService.Util.SetCharacterVisibility(character: Instance, visible: boolean)
	if not character then
		return false
	end

	local transparencyCache = HiddenTransparencyCache[character]
	if visible == false and transparencyCache == nil then
		transparencyCache = {}
		HiddenTransparencyCache[character] = transparencyCache
	end

	for _, object in ipairs(GetTransparencyTargets(character)) do
		if not CanAdjustTransparency(object) then
			continue
		end

		if visible == false then
			if transparencyCache[object] == nil then
				transparencyCache[object] = object.Transparency
			end

			object.Transparency = 1
		else
			object.Transparency = GetOriginalTransparency(transparencyCache, object)
		end
	end

	if visible ~= false then
		HiddenTransparencyCache[character] = nil
	end

	return true
end

function EffectService.Util.FlickerTransparency(target: Instance, duration: number)
	if not target then
		return false
	end

	duration = math.max(duration or 0.15, 0.05)
	local transparencyCache = HiddenTransparencyCache[target]
	local flickerCount = math.max(1, math.floor(duration / 0.08))
	local phaseDuration = duration / (flickerCount * 2)
	local tweens = {}

	for _, object in ipairs(GetTransparencyTargets(target)) do
		if not CanAdjustTransparency(object) then
			continue
		end

		local originalTransparency = GetOriginalTransparency(transparencyCache, object)

		task.spawn(function()
			for _ = 1, flickerCount do
				if not object or object.Parent == nil then
					return
				end

				object.Transparency = 1
				task.wait(phaseDuration)

				if not object or object.Parent == nil then
					return
				end

				local tween = TweenService:Create(object, TweenInfo.new(phaseDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
					Transparency = originalTransparency,
				})
				tween:Play()
				table.insert(tweens, tween)
				task.wait(phaseDuration)
			end

			if object and object.Parent ~= nil then
				object.Transparency = originalTransparency
			end
		end)
	end

	return tweens
end

function EffectService.Util.safeFind(root: Instance?, ...: string): Instance?
	local current = root
	for _, segment in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

function EffectService.Util.playNode(node: Instance?)
	if not node then
		return
	end

	local objects = node:GetDescendants()
	table.insert(objects, node)

	for _, obj in ipairs(objects) do
		local emitDelay = obj:GetAttribute("EmitDelay") or 0
		local emitDuration = obj:GetAttribute("EmitDuration") or 0

		if obj:IsA("ParticleEmitter") then
			local emitCount = obj:GetAttribute("EmitCount") or 1
			local emitRepeat = obj:GetAttribute("EmitRepeat") or 1
			local emitRepeatDelay = obj:GetAttribute("EmitRepeatDelay") or 0

			local function playEmitter()
				for _ = 1, emitRepeat do
					obj:Emit(emitCount)
					if emitRepeatDelay > 0 then
						task.wait(emitRepeatDelay)
					end
				end

				if emitDuration > 0 then
					obj.Enabled = true
					task.delay(emitDuration, function()
						if obj and obj.Parent then
							obj.Enabled = false
						end
					end)
				end
			end

			if emitDelay > 0 then
				task.delay(emitDelay, playEmitter)
			else
				playEmitter()
			end
		elseif obj:IsA("Beam") or obj:IsA("Trail") then
			local function playBeamOrTrail()
				obj.Enabled = true
				if emitDuration > 0 then
					task.delay(emitDuration, function()
						if obj and obj.Parent then
							obj.Enabled = false
						end
					end)
				end
			end

			if emitDelay > 0 then
				task.delay(emitDelay, playBeamOrTrail)
			else
				playBeamOrTrail()
			end
		end
	end
end

function EffectService.Util.setEnabledDescendants(root: Instance?, classAllowSet: { [string]: boolean }, enabled: boolean)
	if not root then
		return
	end

	local function maybeToggle(obj: Instance)
		if classAllowSet[obj.ClassName] and (obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail")) then
			obj.Enabled = enabled
		end
	end

	maybeToggle(root)
	for _, obj in ipairs(root:GetDescendants()) do
		maybeToggle(obj)
	end
end

function EffectService.Util.mountTogglesForLimb(effectRoot: Instance, char: Model, limbName: string, cache: { [string]: any })
	local togglesRoot = EffectService.Util.safeFind(effectRoot, "toggles")
	local sourceFolder = EffectService.Util.safeFind(togglesRoot, limbName)
	local limb = char:FindFirstChild(limbName)
	if not sourceFolder or not limb then
		return
	end

	local bucket = cache[limbName]
	if not bucket then
		bucket = {
			sourceFolder = sourceFolder,
			items = {},
			mounted = false,
		}
		cache[limbName] = bucket
	end

	if bucket.mounted then
		return
	end

	for _, child in ipairs(sourceFolder:GetChildren()) do
		table.insert(bucket.items, {
			instance = child,
			originalParent = child.Parent,
		})
		child.Parent = limb
	end

	bucket.mounted = true
end

function EffectService.Util.setMountedToggleState(cache: { [string]: any }, limbName: string, enabled: boolean, allowedClasses: { string })
	local bucket = cache[limbName]
	if not bucket then
		return
	end

	local classAllowSet: { [string]: boolean } = {}
	for _, className in ipairs(allowedClasses) do
		classAllowSet[className] = true
	end

	for _, entry in ipairs(bucket.items) do
		if entry.instance then
			EffectService.Util.setEnabledDescendants(entry.instance, classAllowSet, enabled)
		end
	end
end

function EffectService.Util.restoreMountedToggles(cache: { [string]: any })
	for _, bucket in pairs(cache) do
		for _, entry in ipairs(bucket.items) do
			local inst = entry.instance
			local originalParent = entry.originalParent
			if inst and inst.Parent and originalParent then
				inst.Parent = originalParent
			end
		end
	end
end

function EffectService.Util.playUserAnimation(char: Model, animationId: string, loopOverride: boolean?): AnimationTrack?
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or animationId == "" then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = cachedAnimationById[animationId]
	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = animationId
		cachedAnimationById[animationId] = animation
	end

	local track = animator:LoadAnimation(animation)
	track:Play()
	if loopOverride ~= nil then
		track.Looped = loopOverride
	end
	return track
end

function EffectService.Util.playRigAnimation(rig: Instance?, animationId: string): AnimationTrack?
	if not rig or animationId == "" then
		return nil
	end

	local animator: Animator? = nil

	local directController = rig:FindFirstChild("AnimationController")
	if directController and directController:IsA("AnimationController") then
		animator = directController:FindFirstChildOfClass("Animator")
	end

	local humanoid = rig:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	else
		if not animator then
			local controller = rig:FindFirstChildWhichIsA("AnimationController", true)
			if controller then
				animator = controller:FindFirstChildOfClass("Animator")
				if not animator then
					animator = Instance.new("Animator")
					animator.Parent = controller
				end
			end
		end
	end

	if not animator then
		return nil
	end

	local animation = cachedAnimationById[animationId]
	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = animationId
		cachedAnimationById[animationId] = animation
	end

	local track = animator:LoadAnimation(animation)
	track:Play()
	return track
end

--@ TrackProjectileCollision - swept-raycast collision + single-shot detonation for a moving
--@ projectile visual. The CALLER moves opts.part; this only watches its path each Heartbeat and
--@ fires opts.onDetonate(impactPosition, reason) EXACTLY ONCE, on the first frame the swept
--@ segment (so a fast projectile cannot tunnel a wall) hits a living non-caster Humanoid, a part
--@ under the map root, or - with a tween - that tween completing at max range.
--@ opts: part BasePart (req) | onDetonate function (req) (pos: Vector3?, reason: target|surface|range)
--@   caster Model? excluded from the sweep | tween Tween? Completed -> range, cancelled on impact
--@   ignore {Instance}? extra exclusions (the Visuals FX folder is always excluded)
--@   mapRoot Instance? default workspace.Terrain.World.Map | lifetime number? sweep cutoff, default 5
--@   snapOnImpact boolean? snap part to contact, default true | targets/surfaces boolean? default true
--@ Returns stop(): cancel tracking WITHOUT detonating.
function EffectService.Util.TrackProjectileCollision(opts: { [string]: any }): () -> ()
	local part: BasePart? = opts.part
	local onDetonate = opts.onDetonate
	if not (part and typeof(onDetonate) == "function") then
		return function() end
	end

	local caster: Instance? = opts.caster
	local tween: Tween? = opts.tween
	local mapRoot = opts.mapRoot or EffectService.Util.safeFind(workspace, "Terrain", "World", "Map")
	local lifetime = tonumber(opts.lifetime) or 5
	local snapOnImpact = opts.snapOnImpact ~= false
	local checkTargets = opts.targets ~= false
	local checkSurfaces = opts.surfaces ~= false

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	--@ The whole VFX folder is always excluded (this projectile + every other effect lives under
	--@ Visuals), so the sweep only ever reports real targets / world geometry, never a self-hit.
	local exclude: { Instance } = { Visuals }
	if caster then
		table.insert(exclude, caster)
	end
	if typeof(opts.ignore) == "table" then
		for _, inst in ipairs(opts.ignore) do
			table.insert(exclude, inst)
		end
	end
	rayParams.FilterDescendantsInstances = exclude

	local function livingTargetFrom(hitInstance: Instance?): Model?
		local model = hitInstance and hitInstance:FindFirstAncestorWhichIsA("Model")
		while model do
			if model ~= caster then
				local hum = model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					return model
				end
			end
			model = model:FindFirstAncestorWhichIsA("Model")
		end
		return nil
	end

	--@ nil -> not a valid impact (fly on); otherwise the reason string for the detonation.
	local function classifyHit(result: RaycastResult?): string?
		if not result then
			return nil
		end
		if checkTargets and livingTargetFrom(result.Instance) then
			return "target"
		end
		if checkSurfaces and mapRoot and result.Instance:IsDescendantOf(mapRoot) then
			return "surface"
		end
		return nil
	end

	local detonated = false
	local collisionConn: RBXScriptConnection? = nil
	local completedConn: RBXScriptConnection? = nil

	local function cleanup()
		if collisionConn then collisionConn:Disconnect(); collisionConn = nil end
		if completedConn then completedConn:Disconnect(); completedConn = nil end
	end

	local function detonate(impactPosition: Vector3?, reason: string)
		if detonated then
			return
		end
		detonated = true
		cleanup()

		--@ Any impact stops the flight; the max-range route (nil position) leaves the part in place.
		if impactPosition then
			if tween then
				tween:Cancel()
			end
			if snapOnImpact and part and part.Parent then
				part.CFrame = part.CFrame.Rotation + impactPosition
			end
		end

		onDetonate(impactPosition, reason)
	end

	local lastPosition = part.Position
	local flightStart = os.clock()

	collisionConn = RunService.Heartbeat:Connect(function()
		if detonated then
			return
		end
		if not (part and part.Parent) then
			cleanup()
			return
		end
		--@ Lifetime guard: never let the sweep outlive the flight if the tween is cancelled elsewhere.
		if os.clock() - flightStart > lifetime + 0.25 then
			cleanup()
			return
		end

		local currentPosition = part.Position
		local segment = currentPosition - lastPosition
		if segment.Magnitude > 1e-3 then
			local result = workspace:Raycast(lastPosition, segment, rayParams)
			local reason = classifyHit(result)
			if reason then
				detonate(result.Position, reason)
				return
			end
		end
		lastPosition = currentPosition
	end)

	if tween then
		completedConn = tween.Completed:Connect(function()
			--@ Reached max range with no valid impact -> detonate in place.
			detonate(nil, "range")
		end)
	end

	return function()
		if detonated then
			return
		end
		detonated = true
		cleanup()
	end
end

--@ TrackServerImpact - single-shot listener for a SERVER-authoritative impact. The server stamps
--@ the caster with character:SetAttribute(opts.attribute, stopPosition); this fires
--@ opts.onImpact(position) EXACTLY ONCE on the first Vector3 it sees, then stops. Lets a moveset
--@ align its visual to where the server landed the hit rather than its own client sweep.
--@ Pair with TrackProjectileCollision and let whichever fires first win.
--@ opts: character Model (req) | attribute string (req) | onImpact function (req) (pos: Vector3)
--@ Returns stop(): cancel listening WITHOUT firing.
function EffectService.Util.TrackServerImpact(opts: { [string]: any }): () -> ()
	local character: Model? = opts.character
	local attribute = opts.attribute
	local onImpact = opts.onImpact
	if not (character and typeof(attribute) == "string" and typeof(onImpact) == "function") then
		return function() end
	end

	local fired = false
	local conn: RBXScriptConnection? = nil

	local function cleanup()
		if conn then conn:Disconnect(); conn = nil end
	end

	--@ Change-only (never reads the value at connect time): the server clears the attribute back
	--@ to nil shortly after each hit, so a stale value from a previous cast can't false-trigger.
	conn = character:GetAttributeChangedSignal(attribute):Connect(function()
		if fired then
			return
		end
		local position = character:GetAttribute(attribute)
		if typeof(position) ~= "Vector3" then
			return
		end
		fired = true
		cleanup()
		onImpact(position)
	end)

	return function()
		if fired then
			return
		end
		fired = true
		cleanup()
	end
end

--@ Methods
function EffectService:SetCFrame(rootCF : CFrame)
	if not self.Effect then return false end

	local finalCF = rootCF * self._Offset

	if self.Effect:IsA("Model") then
		self.Effect:PivotTo(finalCF)
	elseif self.Effect:IsA("BasePart") then
		self.Effect.CFrame = finalCF
	elseif self.Effect:IsA("Attachment") then
		self.Effect.WorldCFrame = finalCF
	end

	return true
end

function EffectService:GroundEffect(maxDistance : number?)
	if not self.Effect then return false end

	self._originalCFrame = self._originalCFrame or (function()

		if self.Effect:IsA("BasePart") then
			return self.Effect.CFrame
		elseif self.Effect:IsA("Model") and self.Effect.PrimaryPart then
			return self.Effect:GetPrimaryPartCFrame()
		elseif self.Effect:IsA("Attachment") then
			return self.Effect.WorldCFrame
		end
		return nil
	end)()

	local origin : Vector3
	local forward : Vector3

	if self.Effect:IsA("BasePart") then
		origin = self.Effect.Position
		forward = self.Effect.CFrame.LookVector
	elseif self.Effect:IsA("Model") and self.Effect.PrimaryPart then
		origin = self.Effect.PrimaryPart.Position
		forward = self.Effect.PrimaryPart.CFrame.LookVector
	elseif self.Effect:IsA("Attachment") then
		origin = self.Effect.WorldPosition
		forward = self.Effect.WorldCFrame.LookVector
	else
		return false
	end

	local distance = maxDistance or 1024
	local direction = Vector3.new(0, -distance, 0)

	local raycastParams = RaycastParams.new()

	if workspace:FindFirstChild("Terrain")
		and workspace.Terrain:FindFirstChild("World")
		and workspace.Terrain.World:FindFirstChild("Map")
	then
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { workspace.Terrain.World.Map }
	else
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { self.Effect }
	end

	local result = workspace:Raycast(origin, direction, raycastParams)

	if result then
		local up = result.Normal.Unit
		local f = (forward - forward:Dot(up) * up)

		if f.Magnitude < 1e-4 then
			local pick = math.abs(up:Dot(Vector3.new(0,1,0))) > 0.99 and Vector3.new(1,0,0) or Vector3.new(0,1,0)
			f = (pick - pick:Dot(up) * up)
		end

		f = f.Unit
		local r = up:Cross(f).Unit
		local alignedCF = CFrame.fromMatrix(result.Position, r, up)

		self:SetCFrame(alignedCF)
	else

		if self._originalCFrame then
			self:SetCFrame(self._originalCFrame)
		end
	end

	return true
end

function EffectService:ZeroAttachmentOrientation()
	if not self.Effect then return end
	for _, att in ipairs(self.Effect:GetDescendants()) do

		if att:IsA("Attachment") then
			att.CFrame = CFrame.new(att.Position)
			att.Axis = Vector3.new(1, 0, 0)
			att.SecondaryAxis = Vector3.new(0, 1, 0)
		end
	end
end

function EffectService:SetParent(Parent : {Any})
	if not self.Effect then return false end

	if self.Effect then
		self.Effect.Parent = Parent
	end

	return true
end

function EffectService:SetRemoval(Time : number)
	if not self.Effect then return false end

	task.delay(Time, function()
		self:Destroy()
	end)

	return true
end

function EffectService:AdjustColor(Color : Color3, IgnoreList : {string})
	if not self.Effect then return false end

	IgnoreList = IgnoreList or {};

	for _, particles in GetEffectObjects(self.Effect) do
		if (particles:IsA("ParticleEmitter") or particles:IsA("Trail") or particles:IsA("Beam"))
			and not table.find(IgnoreList, particles.Name)
		then
			particles.Color = ColorSequence.new(Color, Color)
		end
	end
end

function EffectService:Play(Blacklist : {Array})
	if not self.Effect then return false end

	--@ Root INCLUDED: the asset itself may be the Trail / emitter.
	local Objects = GetEffectObjects(self.Effect)

	--@ Blacklist Specific Instances
	--@ Prevent Specific Instances from being Emitted

	Blacklist = Blacklist or {}

	for _, Object in ipairs(Objects) do
		--@ Trails and Beams are streaks, not bursts - they play by being ENABLED (optionally
		--@ delayed, and auto-disabled after EmitDuration) rather than by emitting a count.
		if (Object:IsA("Trail") or Object:IsA("Beam")) and not MatchesList(Blacklist, Object) then
			local StreakDelay = Object:GetAttribute("EmitDelay") or 0
			local StreakDuration = Object:GetAttribute("EmitDuration") or 0

			local function enableStreak()
				if not Object or Object.Parent == nil then
					return
				end

				Object.Enabled = true

				if StreakDuration > 0 then
					task.delay(StreakDuration, function()
						if Object and Object.Parent then
							Object.Enabled = false
						end
					end)
				end
			end

			if StreakDelay > 0 then
				task.delay(StreakDelay, enableStreak)
			else
				enableStreak()
			end
		end

		if Object:IsA("PointLight") then
			Object.Enabled = true	

			TweenService:Create(Object, TweenInfo.new(Object:GetAttribute("FadeTime") or 1), {
				Range = 0,
			}):Play()
		end
		if Object:IsA('ParticleEmitter') then

			--@ Get Object Attributes For Particles
			local EmitCount = Object:GetAttribute('EmitCount') or 1
			local EmitRepeat = Object:GetAttribute('EmitRepeat') or 1
			local EmitDelay = Object:GetAttribute('EmitDelay') or 0

			if EmitDelay > 0 then
				task.delay(EmitDelay, function()
					for _ = 1, EmitRepeat do
						if not table.find(Blacklist, Object) and not table.find(Blacklist, Object.Name) then
							Object:Emit(math.ceil(EmitCount / (self.EmitDivider or 1)))
						end
						task.wait(EmitDelay)
					end
				end)
			else
				for _ = 1, EmitRepeat do
					if not table.find(Blacklist, Object) and not table.find(Blacklist, Object.Name) then
						Object:Emit(math.ceil(EmitCount / self.EmitDivider))
					end
				end
			end

		end
	end

	return true
end

--@ Emit Particle 
function EffectService:Emit(Count : number, Blacklist : {Array})
	if not self.Effect then return false end

	Count = Count or 1 
	Blacklist = Blacklist or {}

	for _, Object in ipairs(GetEffectObjects(self.Effect)) do
		if Object:IsA('ParticleEmitter') then
			if not table.find(Blacklist, Object) and not table.find(Blacklist, Object.Name) then
				if Object:GetAttribute("EmitCount") then
					Object:Emit(math.ceil(Object:GetAttribute("EmitCount") / self.EmitDivider))
				else
					Object:Emit(math.ceil(Count / self.EmitDivider))
				end
			end
		end
	end

	return true
end

function EffectService:AdjustProperty(Properties : {}, IgnoreList : {})
	if not self.Effect then return false end

	IgnoreList = IgnoreList or {}

	for _, particle in GetEffectObjects(self.Effect) do
		if not IsVisualInstance(particle) or table.find(IgnoreList, particle.Name) then
			continue
		end

		for property, value in Properties do
			if type(value)=="table" then
				particle[property] = debug and value[2] or value[1]
			else
				particle[property] = value
			end
		end

	end
end

--@ Toggle Particle
function EffectService:Toggle(Toggle : boolean, Blacklist : {Array})
	if not self.Effect then return false end

	Blacklist = Blacklist or {}

	--@ Root INCLUDED, so an asset that IS a Trail / Beam / emitter toggles like a nested one.
	for _, Object in GetEffectObjects(self.Effect) do
		if IsVisualInstance(Object) and not MatchesList(Blacklist, Object) then
			Object.Enabled = if Toggle ~= nil then Toggle else not Object.Enabled
		end
	end

	return true
end

function EffectService:ToggleAfterTime(Toggle : boolean, Duration : number, Blacklist : {Array})
	if not self.Effect then return false end

	Blacklist = Blacklist or {}

	task.delay(Duration or 0, function()
		if not self.Effect then
			return
		end

		for _, Object in GetEffectObjects(self.Effect) do
			if IsVisualInstance(Object) and not MatchesList(Blacklist, Object) then
				Object.Enabled = if Toggle ~= nil then Toggle else not Object.Enabled
			end
		end
	end)

	return true
end

--@ Change Color of particles
function EffectService:Color(Color : Color3, Whitelist : {Array})
	if not self.Effect then return false end

	Whitelist = Whitelist or {}

	for _, Object in GetEffectObjects(self.Effect) do
		if Object:IsA("ParticleEmitter") or Object:IsA("Trail") or Object:IsA("Beam") then
			if table.find(Whitelist, Object) or table.find(Whitelist, Object.Name) then
				--if string.find(Object.Name, 'COLOR') then
				local H, S, V = Color:ToHSV()
				local NewColor = ColorSequence.new(Color3.fromHSV(H, S, V/2.25))
				Object.Color = NewColor
				--end
			end
		end
	end

	return true
end

--@ Emit For Set Duration
function EffectService:EmitForSeconds(Duration: number, Blacklist: table)
	if not self.Effect then return false end

	local _objects = {}
	Duration = Duration or 1
	Blacklist = Blacklist or {}

	--@ Root INCLUDED, and Trails / Beams stream for the duration exactly like an enabled emitter.
	for _, Object in ipairs(GetEffectObjects(self.Effect)) do
		if IsVisualInstance(Object) then
			local EmitDelay = Object:GetAttribute('EmitDelay') or 0

			if not MatchesList(Blacklist, Object) then
				if EmitDelay > 0 then
					task.delay(EmitDelay, function()
						Object.Enabled = true
					end)
				else
					Object.Enabled = true
				end
				table.insert(_objects, Object)
			end
		end
	end

	task.delay(Duration, function()
		for _, Object in ipairs(_objects) do
			if not Object then continue end
			Object.Enabled = false
		end
	end)

	return true
end

-- Fades out transparency for Trail objects (deltaTime compensated)
function EffectService:FadeOutTrails(FadeTime: number, Blacklist: {Array})
	if not self.Effect then return false end

	FadeTime = FadeTime or 1
	Blacklist = Blacklist or {}

	local trails = {}

	-- Collect all Trail instances and store their original transparency (root included, so an
	-- asset that IS a Trail fades instead of being skipped)
	for _, obj in ipairs(GetEffectObjects(self.Effect)) do
		if obj:IsA("Trail") and not MatchesList(Blacklist, obj) then
			table.insert(trails, {
				Instance = obj,
				OriginalTransparency = obj.Transparency or NumberSequence.new(0)
			})
		end
	end

	-- Store fade data
	local fadeData = {
		StartTime = os.clock(),
		Duration = FadeTime,
		Elapsed = 0,
		Trails = trails
	}

	-- Create heartbeat connection with deltaTime compensation
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		fadeData.Elapsed = fadeData.Elapsed + deltaTime
		local progress = math.clamp(fadeData.Elapsed / fadeData.Duration, 0, 1)

		-- Update transparency for each trail
		for _, trailData in ipairs(fadeData.Trails) do
			local newKeypoints = {}
			for _, kp in ipairs(trailData.OriginalTransparency.Keypoints) do
				local newValue = kp.Value + (1 - kp.Value) * progress
				table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newValue))
			end
			trailData.Instance.Transparency = NumberSequence.new(newKeypoints)
		end

		-- Clean up when complete
		if progress >= 1 then
			connection:Disconnect()
			if self._transparencyConnections then
				table.remove(self._transparencyConnections, table.find(self._transparencyConnections, connection))
			end
		end
	end)

	-- Store connection for potential cleanup
	if not self._transparencyConnections then
		self._transparencyConnections = {}
	end
	table.insert(self._transparencyConnections, connection)

	return true
end

-- Fades out transparency for Beam objects (deltaTime compensated)
function EffectService:FadeOutBeams(FadeTime: number, Blacklist: {Array})
	if not self.Effect then return false end

	FadeTime = FadeTime or 1
	Blacklist = Blacklist or {}

	local beams = {}

	-- Collect all Beam instances and store their original transparency (root included)
	for _, obj in ipairs(GetEffectObjects(self.Effect)) do
		if obj:IsA("Beam") and not MatchesList(Blacklist, obj) then
			table.insert(beams, {
				Instance = obj,
				OriginalTransparency = obj.Transparency or NumberSequence.new(0)
			})
		end
	end

	-- Store fade data
	local fadeData = {
		StartTime = os.clock(),
		Duration = FadeTime,
		Elapsed = 0,
		Beams = beams
	}

	-- Create heartbeat connection with deltaTime compensation
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		fadeData.Elapsed = fadeData.Elapsed + deltaTime
		local progress = math.clamp(fadeData.Elapsed / fadeData.Duration, 0, 1)

		-- Update transparency for each beam
		for _, beamData in ipairs(fadeData.Beams) do
			local newKeypoints = {}
			for _, kp in ipairs(beamData.OriginalTransparency.Keypoints) do
				local newValue = kp.Value + (1 - kp.Value) * progress
				table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newValue))
			end
			beamData.Instance.Transparency = NumberSequence.new(newKeypoints)
		end

		-- Clean up when complete
		if progress >= 1 then
			connection:Disconnect()
			if self._transparencyConnections then
				table.remove(self._transparencyConnections, table.find(self._transparencyConnections, connection))
			end
		end
	end)

	-- Store connection for potential cleanup
	if not self._transparencyConnections then
		self._transparencyConnections = {}
	end
	table.insert(self._transparencyConnections, connection)

	return true
end

-- Fades out transparency for ParticleEmitters (deltaTime compensated)
function EffectService:FadeOutParticles(FadeTime: number, Blacklist: {Array})
	if not self.Effect then return false end

	FadeTime = FadeTime or 1
	Blacklist = Blacklist or {}

	local emitters = {}

	-- Collect all ParticleEmitter instances and store their original transparency (root included)
	for _, obj in ipairs(GetEffectObjects(self.Effect)) do
		if obj:IsA("ParticleEmitter") and not MatchesList(Blacklist, obj) then
			table.insert(emitters, {
				Instance = obj,
				OriginalTransparency = obj.Transparency or NumberSequence.new(0)
			})
		end
	end

	-- Store fade data
	local fadeData = {
		StartTime = os.clock(),
		Duration = FadeTime,
		Elapsed = 0,
		Emitters = emitters
	}

	-- Create heartbeat connection with deltaTime compensation
	local connection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		fadeData.Elapsed = fadeData.Elapsed + deltaTime
		local progress = math.clamp(fadeData.Elapsed / fadeData.Duration, 0, 1)

		-- Update transparency for each emitter
		for _, emitterData in ipairs(fadeData.Emitters) do
			local newKeypoints = {}
			for _, kp in ipairs(emitterData.OriginalTransparency.Keypoints) do
				local newValue = kp.Value + (1 - kp.Value) * progress
				table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newValue))
			end
			emitterData.Instance.Transparency = NumberSequence.new(newKeypoints)
		end

		-- Clean up when complete
		if progress >= 1 then
			connection:Disconnect()
			if self._transparencyConnections then
				table.remove(self._transparencyConnections, table.find(self._transparencyConnections, connection))
			end
		end
	end)

	-- Store connection for potential cleanup
	if not self._transparencyConnections then
		self._transparencyConnections = {}
	end
	table.insert(self._transparencyConnections, connection)

	return true
end

function EffectService:AnimateFlipbook(Time, Textures)
	if not self.Effect then return false end
	local Hour = game.Lighting.ClockTime

	if Hour < 7 or Hour >= 18 then
		self.Effect.Decal.Color3 = Color3.new(
			self.Effect.Decal.Color3.R * 2, 
			self.Effect.Decal.Color3.G * 2, 
			self.Effect.Decal.Color3.B * 2
		)
	end

	for i = 1, #Textures do
		self.Effect.Decal.Texture = "rbxassetid://" .. Textures[i]
		task.wait(Time / #Textures)
	end
end

function EffectService:PlayFlipbook(Flipbook : {any}, Decal : Decal, Settings : {[string]: any}?)
	if not self.Effect then return false end
	Settings = Settings or {}

	local SlashDecal = Decal or
		self.Effect:FindFirstChild("Decal") 

	if not SlashDecal then 
		return 
	end

	SlashDecal.Transparency = 0
	SlashDecal.Texture = ""	

	local FlipbookDissipate = Settings.Fade or 0.35 
	local FlipbookSpeed = tonumber(Settings.Speed) or 1

	if FlipbookSpeed <= 0 then
		FlipbookSpeed = 1
	end

	local FlipbookPlaybackDuration = FlipbookDissipate / FlipbookSpeed
	local FlipbookDelay = SlashDecal:GetAttribute("EmitDelay") or 0

	task.spawn(function()	
		if self.Effect then
			if FlipbookDelay > 0 then
				task.wait(FlipbookDelay)
			end

			local StartInterval = os.clock()

			repeat

				local _delta = (os.clock() - StartInterval) / FlipbookPlaybackDuration
				local currentTex = Flipbook[math.clamp(math.floor(_delta * #Flipbook) + 1, 1, #Flipbook)]
				SlashDecal.Texture = tostring(currentTex)

				RunService.Heartbeat:Wait()
			until os.clock() - StartInterval >= FlipbookPlaybackDuration

			SlashDecal.Texture = ""

			TweenService:Create(SlashDecal, TweenInfo.new(FlipbookDissipate, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Transparency = 1
			}):Play();			
		end
	end)
end

-- Fades out all visual elements (trails, beams, and particles)
function EffectService:FadeOutAll(FadeTime: number, Blacklist: {Array})
	if not self.Effect then return false end

	FadeTime = FadeTime or 1
	Blacklist = Blacklist or {}

	self:FadeOutTrails(FadeTime, Blacklist)
	self:FadeOutBeams(FadeTime, Blacklist)
	self:FadeOutParticles(FadeTime, Blacklist)

	return true
end

-- Cleans up all active transparency animations
function EffectService:CleanupTransparencyAnimations()
	if not self._transparencyConnections then return end

	for _, connection in ipairs(self._transparencyConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	self._transparencyConnections = nil
end

function EffectService:Destroy()
	if self._destroyed then return end
	self._destroyed = true

	self:_CleanupCancellable()
	self:CleanupTransparencyAnimations()

	if self.Effect then
		self.Effect:Destroy()
		self.Effect = nil
	end

	self.Owner = nil
	self.CancellableCallback = nil
	self.CancellableWhitelist = nil
end

return EffectService