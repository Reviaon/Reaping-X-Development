-- Observers never simulate a ragdoll they don't own. The simulator streams its pose (root CFrame
-- + every joint's relative rotation, one server timestamp), and an observer keeps the rig's
-- joints rigid and plays that pose back as joint Transforms on a jitter-buffered clock, with the
-- root anchored and written from the same sample. The whole visible body therefore sits on one
-- timeline: it cannot tear at the hips, and "ragdoll on/off" lands exactly where the motion does,
-- because both are in the same packet.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Codec = require(script.Parent.Codec)
local Rig = require(script.Parent.Rig)
local Simulator = require(script.Parent.Simulator)

local Stream = {}

local IS_SERVER = RunService:IsServer()

Stream.RADIUS = 400
Stream.PACKET_LIMIT = 900
Stream.MIN_DELAY = 0.05
Stream.MAX_DELAY = 0.35
Stream.STALE = 1
Stream.FADE = 0.15
Stream.TAKEOVER_BLEND = 0.15
Stream.BUFFER = 40

local remote: UnreliableRemoteEvent
local idToModel: { [number]: Model } = {}

local function capture(rig, flags: number): buffer
	local rotations = table.create(#rig.all)
	for i, j in rig.all do
		rotations[i] = Simulator.relative(j)
	end
	local b = buffer.create(Codec.recordSize(#rotations))
	Codec.write(b, 0, rig.id, flags, workspace:GetServerTimeNow(), rig.root.CFrame, rotations)
	return b
end

-- ---------------------------------------------------------------------------------------------
-- Server: queue records (own NPCs + relayed client uploads), batch per recipient each Heartbeat.

local pending: { { record: buffer, origin: Vector3, exclude: Player? } } = {}

local function flush()
	if #pending == 0 then
		return
	end
	local queue = pending
	pending = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local mine = {}
		for _, item in queue do
			if item.exclude ~= player and (item.origin - root.Position).Magnitude <= Stream.RADIUS then
				table.insert(mine, item.record)
			end
		end
		if #mine > 0 then
			for _, packet in Codec.pack(mine, Stream.PACKET_LIMIT) do
				remote:FireClient(player, packet)
			end
		end
	end
end

local function onUpload(player: Player, packet: any)
	if typeof(packet) ~= "buffer" then
		return
	end
	local len = buffer.len(packet)
	if len < Codec.recordSize(0) or len > Stream.PACKET_LIMIT then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local id, _, size = Codec.peek(packet, 0)
	if size ~= len or id ~= character:GetAttribute("RagdollId") then
		return
	end
	local stamp = buffer.readf64(packet, 3)
	local now = workspace:GetServerTimeNow()
	if stamp ~= stamp or stamp < now - 2 or stamp > now + 0.5 then
		return
	end
	local origin = Vector3.new(buffer.readf32(packet, 11), buffer.readf32(packet, 15), buffer.readf32(packet, 19))
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (origin - root.Position).Magnitude > 100 then
		origin = root.Position
	end
	table.insert(pending, { record = packet, origin = origin, exclude = player })
end

-- ---------------------------------------------------------------------------------------------
-- Client: observers.

local observers: { [Model]: any } = {}
local localPlayer = Players.LocalPlayer

local function setDebug(obs, text: string?)
	if not text then
		if obs.gui then
			obs.gui:Destroy()
			obs.gui = nil
		end
		return
	end
	if not obs.gui then
		local gui = Instance.new("BillboardGui")
		gui.Name = "RagdollStreamDebug"
		gui.Size = UDim2.fromOffset(220, 40)
		gui.StudsOffset = Vector3.new(0, 3.5, 0)
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.4
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Parent = gui
		gui.Adornee = obs.rig.root
		gui.Parent = obs.rig.root
		obs.gui = gui
	end
	(obs.gui:FindFirstChildOfClass("TextLabel") :: TextLabel).Text = text
end

local function holdRigid(obs)
	for _, j in obs.rig.joints do
		if not j.motor.Enabled then
			j.motor.Enabled = true
		end
	end
end

local function sampleAt(obs, t: number)
	local samples = obs.samples
	local n = #samples
	if n == 0 then
		return nil
	end
	if t <= samples[1].t then
		return samples[1].root, samples[1].rotations, samples[1]
	end
	for i = n - 1, 1, -1 do
		local a = samples[i]
		if a.t <= t then
			local b = samples[i + 1]
			local alpha = math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1)
			local rotations = table.create(#a.rotations)
			for k, ra in a.rotations do
				local rb = b.rotations[k]
				rotations[k] = if rb then ra:Lerp(rb, alpha) else ra
			end
			return a.root:Lerp(b.root, alpha), rotations, a
		end
	end
	local last = samples[n]
	return last.root, last.rotations, last
end

local function takeover(obs, root: CFrame)
	local rig = obs.rig
	obs.active = true
	obs.savedAnchored = rig.root.Anchored
	obs.offset = rig.root.Position - root.Position
	if obs.offset.Magnitude > 20 then
		obs.offset = Vector3.zero
	end
	obs.offsetStart = os.clock()
	rig.root.Anchored = true
	obs.fade = nil
end

local function release(obs)
	local rig = obs.rig
	obs.active = false
	if obs.savedAnchored ~= nil and rig.root.Parent then
		rig.root.Anchored = obs.savedAnchored
	end
	obs.savedAnchored = nil
	local last = obs.samples[#obs.samples]
	obs.releasedAt = last and last.t or workspace:GetServerTimeNow()
	obs.samples = {}
	if obs.lastRotations then
		obs.fade = { from = obs.lastRotations, start = os.clock() }
	end
end

local function applyPose(obs, root: CFrame?, rotations)
	local rig = obs.rig
	for i, j in rig.all do
		local r = rotations[i]
		if r then
			j.motor.Transform = r
		end
	end
	if root then
		local offset = obs.offset
		if offset then
			local a = (os.clock() - obs.offsetStart) / Stream.TAKEOVER_BLEND
			if a >= 1 then
				obs.offset = nil
			else
				root = root + offset * (1 - a)
			end
		end
		rig.root.CFrame = root
	end
end

local function observerPreAnimation()
	for _, obs in observers do
		if obs.fade then
			for _, j in obs.rig.all do
				j.motor.Transform = CFrame.identity
			end
		end
	end
end

local function observerPreSimulation()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, obs in observers do
		if not model.Parent then
			observers[model] = nil
			continue
		end
		local rig = obs.rig
		local wantsRigid = obs.active or obs.fade or model:GetAttribute("RagdollEnabled") == true
		if wantsRigid and Stream.mode() == "Stream" then
			holdRigid(obs)
		end

		local renderT = now - obs.delay
		if not obs.active and #obs.samples > 0 and renderT >= obs.samples[1].t then
			local root = obs.samples[1].root
			takeover(obs, root)
		end

		if obs.active then
			local root, rotations, base = sampleAt(obs, renderT)
			if root then
				obs.renderRoot = root
				obs.lastRotations = rotations
				applyPose(obs, root, rotations)
			end
			local samples = obs.samples
			while #samples > 2 and samples[2].t < renderT do
				table.remove(samples, 1)
			end
			local last = samples[#samples]
			local ended = last and bit32.band(last.flags, Codec.FINAL) ~= 0 and renderT >= last.t
			local starved = clock - obs.received > Stream.STALE and model:GetAttribute("RagdollEnabled") ~= true
			if ended or starved then
				release(obs)
			end
			if obs.debug then
				setDebug(obs, ("STREAM %s  delay %dms  buf %d"):format(
					if base and bit32.band(base.flags, Codec.RAGDOLLED) ~= 0 then "ragdoll" else "tail",
					math.round(obs.delay * 1000),
					#samples
				))
			end
		elseif obs.fade then
			local a = (clock - obs.fade.start) / Stream.FADE
			if a >= 1 then
				obs.fade = nil
			else
				for i, j in rig.all do
					local from = obs.fade.from[i]
					if from then
						j.motor.Transform = from:Lerp(j.motor.Transform, a * a * (3 - 2 * a))
					end
				end
			end
		elseif obs.debug then
			setDebug(obs, ("idle  delay %dms"):format(math.round(obs.delay * 1000)))
		end
	end
end

local function observerPreRender()
	for _, obs in observers do
		if obs.active and obs.renderRoot then
			local root = obs.renderRoot
			if obs.offset then
				local a = (os.clock() - obs.offsetStart) / Stream.TAKEOVER_BLEND
				if a < 1 then
					root = root + obs.offset * (1 - a)
				end
			end
			obs.rig.root.CFrame = root
		end
	end
end

local function onPacket(packet: buffer)
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local o, len = 0, buffer.len(packet)
	while o < len do
		local ok, record, nextO = pcall(Codec.read, packet, o)
		if not ok then
			return
		end
		o = nextO
		local model = idToModel[record.id]
		local obs = model and observers[model]
		if not obs or (obs.releasedAt and record.t <= obs.releasedAt) then
			continue
		end
		local latency = now - record.t
		if not obs.age then
			obs.age, obs.jitter = latency, 0
		else
			obs.age += (latency - obs.age) * 0.1
			obs.jitter += (math.abs(latency - obs.age) - obs.jitter) * 0.1
		end
		local target = math.clamp(obs.age + 1 / Simulator.SEND_RATE + 2 * obs.jitter + 1 / 60, Stream.MIN_DELAY, Stream.MAX_DELAY)
		if obs.active then
			obs.delay += math.clamp(target - obs.delay, -0.01, 0.01)
		else
			obs.delay = target
		end
		obs.received = clock

		local samples = obs.samples
		local i = #samples
		while i > 0 and samples[i].t > record.t do
			i -= 1
		end
		if not (samples[i] and samples[i].t == record.t) then
			table.insert(samples, i + 1, record)
			if #samples > Stream.BUFFER then
				table.remove(samples, 1)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Native mode (for A/B): observers stop solving the rig's constraints locally while it is
-- ragdolled, so the parts are pure receivers of native physics replication.

local function nativeObserve(obs, ragdolled: boolean)
	if ragdolled and not obs.nativeSaved then
		local saved = {}
		for _, j in obs.rig.joints do
			for _, c in { j.socket, j.muscle } do
				saved[c] = c.Enabled
				c.Enabled = false
			end
		end
		obs.nativeSaved = saved
	elseif not ragdolled and obs.nativeSaved then
		for c, enabled in obs.nativeSaved do
			c.Enabled = enabled
		end
		obs.nativeSaved = nil
	end
end

-- ---------------------------------------------------------------------------------------------

local module = script.Parent

function Stream.mode(): string
	return module:GetAttribute("Replication") or "Stream"
end

function Stream.send(rig, flags: number)
	if Stream.mode() ~= "Stream" or not rig.id then
		return
	end
	local record = capture(rig, flags)
	if IS_SERVER then
		table.insert(pending, { record = record, origin = rig.root.Position })
	else
		remote:FireServer(record)
	end
end

function Stream.observe(rig)
	local model = rig.model
	if observers[model] or model == (localPlayer and localPlayer.Character) then
		return
	end
	local obs = {
		rig = rig,
		samples = {},
		delay = 0.12,
		received = 0,
		active = false,
		debug = module:GetAttribute("Debug") == true,
	}
	observers[model] = obs
	idToModel[rig.id] = model
	local function onRagdoll()
		local on = model:GetAttribute("RagdollEnabled") == true
		nativeObserve(obs, on and Stream.mode() == "Native")
	end
	obs.conn = model:GetAttributeChangedSignal("RagdollEnabled"):Connect(onRagdoll)
	onRagdoll()
end

function Stream.forget(model: Model)
	local obs = observers[model]
	if not obs then
		return
	end
	if obs.active then
		release(obs)
	end
	nativeObserve(obs, false)
	setDebug(obs, nil)
	if obs.conn then
		obs.conn:Disconnect()
	end
	observers[model] = nil
	if idToModel[obs.rig.id] == model then
		idToModel[obs.rig.id] = nil
	end
end

function Stream.setDebug(enabled: boolean)
	for _, obs in observers do
		obs.debug = enabled
		if not enabled then
			setDebug(obs, nil)
		end
	end
end

function Stream.start(remoteEvent: UnreliableRemoteEvent)
	remote = remoteEvent
	if IS_SERVER then
		remote.OnServerEvent:Connect(onUpload)
		RunService.Heartbeat:Connect(flush)
	else
		remote.OnClientEvent:Connect(onPacket)
		RunService.PreAnimation:Connect(observerPreAnimation)
		RunService.PreSimulation:Connect(observerPreSimulation)
		RunService.PreRender:Connect(observerPreRender)
	end
end

return Stream
