local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local AnimationVisualsHandler = Jloader.CreateHandler({ Name = script.Name })

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@self/Config")

local GlobalFunctions = Jloader.GlobalFunctions

local visualsById = {}
local watched = setmetatable({}, { __mode = "k" })

local function find(root: Instance, path: { string }): Instance?
	local found = root

	for _, segment in path do
		found = found and found:FindFirstChild(segment)
	end

	return found
end

local function idOf(animationId: string?): string?
	return animationId and string.match(animationId, "(%d+)%D*$")
end

local function index()
	local library = find(ReplicatedStorage, Config.Animations)
	if not library then return end

	for name, entries in Config.Visuals do
		local animation = library:FindFirstChild(name, true)
		local id = animation and animation:IsA("Animation") and idOf(animation.AnimationId)

		if id then
			visualsById[id] = entries
		end
	end
end

local function anchorOf(character: Model): CFrame?
	local anchor = character:GetAttribute(Config.AnchorAttribute)
	if typeof(anchor) == "CFrame" then return anchor end

	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame
end

local function template(name: string): Instance?
	local holder = find(ReplicatedStorage, Config.Assets)
	holder = holder and holder:FindFirstChild(name)

	return holder and holder:FindFirstChild(name)
end

local function ignoreList(): { Instance }
	local list = {}

	for _, path in { Config.LivePath, Config.Parent } do
		local found = find(workspace, path)

		if found then
			table.insert(list, found)
		end
	end

	return list
end

local function torsoOf(character: Model): BasePart?
	for _, name in Config.TorsoParts do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then return part end
	end

	return nil
end

local function travelFrame(character: Model): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local position = (torsoOf(character) or root).Position
	local velocity = root.AssemblyLinearVelocity
	local fallback = root.CFrame.LookVector
	local direction = if velocity.Magnitude > 1 then velocity.Unit else fallback
	local up = if math.abs(direction.Y) > 0.98 then fallback else Vector3.yAxis

	return CFrame.lookAt(position, position + direction, up)
end

local function holdWhileAirborne(effect, character: Model, follow: boolean?)
	local airborne = Config.Airborne
	local root = character:FindFirstChild("HumanoidRootPart")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList()

	local began = os.clock()
	local landed
	local connection

	connection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local alive = root ~= nil and root.Parent ~= nil and effect.Effect ~= nil and effect.Effect.Parent ~= nil

		if follow and alive then
			local cframe = travelFrame(character)

			if cframe then
				effect:SetCFrame(cframe)
			end
		end

		if not landed then
			local elapsed = now - began
			local grounded = alive and elapsed >= airborne.MinTime
				and workspace:Raycast(root.Position, Vector3.new(0, -airborne.GroundDistance, 0), params) ~= nil

			if alive and not grounded and elapsed < airborne.MaxTime then return end

			landed = now
			effect:FadeOutParticles(airborne.Fade)
		end

		if alive and now - landed < airborne.Fade then return end

		connection:Disconnect()
		effect:Toggle(false)
		effect:SetRemoval(airborne.Linger)
	end)
end

local function emit(entry, character: Model, start: CFrame?)
	local source = template(entry.Effect)
	if not source then return end

	local host = character

	if entry.Anchor == "Partner" then
		host = GlobalFunctions.PairSceneService.PartnerOf(character)
		if not host then return end
	end

	local cframe = if entry.Anchor == "Start" then start elseif entry.Follow then travelFrame(host) else anchorOf(host)
	if not cframe then return end

	local effect = GlobalFunctions.EffectService.new({ Effect = source })

	effect:SetCFrame(cframe)
	effect:SetParent(find(workspace, Config.Parent) or workspace)

	local root = host:FindFirstChild("HumanoidRootPart")

	if entry.Attach and root then
		effect:Weld(root)
	end

	if entry.Airborne then
		holdWhileAirborne(effect, host, entry.Follow)
		return
	end

	GlobalFunctions.ForgeVFX.emit(effect.Effect)
	effect:SetRemoval(Config.Lifetime)
end

local function onTrack(character: Model, track: AnimationTrack)
	local animation = track.Animation
	local entries = animation and visualsById[idOf(animation.AnimationId)]
	if not entries then return end

	local start = anchorOf(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local connections = {}
	local pending = {}
	local rise = -math.huge
	local full

	local function fire(entry)
		if track.WeightTarget < Config.MinWeight then return end

		if entry.Kick then
			local camera = character == Players.LocalPlayer.Character and Jloader.GetHandler("CameraHandler")

			if camera and camera.Kick then
				camera:Kick(entry.Kick)
			end

			return
		end

		emit(entry, character, start)
	end

	local function judge(position: number)
		if full ~= nil then return end

		if root and root.Parent then
			rise = math.max(rise, root.AssemblyLinearVelocity.Y)
		end

		if rise >= Config.FullJump.MinRise then
			full = true
		elseif position >= Config.FullJump.Window then
			full = false
		end
	end

	for _, entry in entries do
		if entry.Marker then
			table.insert(connections, track:GetMarkerReachedSignal(entry.Marker):Connect(function()
				fire(entry)
			end))
		elseif entry.At then
			for _, time in if typeof(entry.At) == "table" then entry.At else { entry.At } do
				table.insert(pending, { Entry = entry, Time = time })
			end
		end
	end

	if #pending > 0 then
		local fired = {}
		local last = 0

		table.insert(connections, RunService.Heartbeat:Connect(function()
			local position = track.TimePosition

			if position < last then
				table.clear(fired)
			end

			last = position
			judge(position)

			for _, event in pending do
				if fired[event] or position < event.Time then continue end
				if event.Entry.FullJump and full == nil then continue end

				fired[event] = true

				if full ~= false or not event.Entry.FullJump then
					fire(event.Entry)
				end
			end
		end))
	end

	table.insert(connections, track.Stopped:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end))
end

local function watch(character: Instance)
	if watched[character] or not character:IsA("Model") then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5))

	if not animator or watched[character] then return end

	watched[character] = animator.AnimationPlayed:Connect(function(track)
		onTrack(character, track)
	end)
end

function AnimationVisualsHandler:Load()
	index()

	task.spawn(function()
		local live = workspace

		for _, segment in Config.LivePath do
			live = live:WaitForChild(segment)
		end

		for _, character in live:GetChildren() do
			task.spawn(watch, character)
		end

		live.ChildAdded:Connect(function(character)
			task.spawn(watch, character)
		end)
	end)
end

return AnimationVisualsHandler
