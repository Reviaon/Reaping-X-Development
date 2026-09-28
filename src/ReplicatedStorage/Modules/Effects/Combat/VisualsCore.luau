local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatusLibrary = require(ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("CharacterLibrary"):WaitForChild("StatusLibrary"))

local VisualsCore = {}

local DEFAULT_FPS = 60
local DEFAULT_LIFETIME = 3

local DEFAULT_PREFIXES = { "Attack", "Hit" }

local function ReadAssets(controller, settings)
	return controller.GetPath:ReadPath(settings.Assets)
end

local function FindAsset(assets, settings, comboIndex)
	local prefixes = settings.Prefix and { settings.Prefix } or DEFAULT_PREFIXES

	for _, prefix in prefixes do
		local asset = assets:FindFirstChild(prefix .. comboIndex)
		if asset then return asset end
	end

	return nil
end

local function FindNamedAsset(assets, name)
	if not assets or typeof(name) ~= "string" then return nil end

	return assets:FindFirstChild(name)
end

local function NormalizeShots(entry, out)
	out = out or {}

	if typeof(entry) == "string" then
		table.insert(out, { Asset = entry })
	elseif typeof(entry) == "table" then
		if entry.Asset then
			table.insert(out, entry)
		else
			for _, nested in entry do
				NormalizeShots(nested, out)
			end
		end
	end

	return out
end

local function FindUnder(root, name)
	if not root or typeof(name) ~= "string" then return nil end

	return root:FindFirstChild(name) or root:FindFirstChild(name, true)
end

local function NormalizeAfterImages(entry, out)
	out = out or {}

	if typeof(entry) == "number" then
		table.insert(out, { Frame = entry })
	elseif typeof(entry) == "table" then
		if typeof(entry.Frame) == "number" then
			table.insert(out, entry)
		else
			for _, nested in entry do
				NormalizeAfterImages(nested, out)
			end
		end
	end

	return out
end

local function Resolve(spec, settings, key, default)
	local value = spec[key]
	if value ~= nil then return value end

	value = settings[key]
	if value ~= nil then return value end

	return default
end

local function ApplySyncPosition(effect: Instance, enabled: boolean)
	for _, descendant in effect:GetDescendants() do
		if descendant:IsA("Model") or descendant:GetAttribute("SyncPosition") ~= nil then
			descendant:SetAttribute("SyncPosition", enabled)
		end
	end
end

local function CancelList(spec, settings)
	local cancelOn = Resolve(spec, settings, "CancelOn", StatusLibrary.HitYield)
	return typeof(cancelOn) == "table" and cancelOn or nil
end

local function IsInterrupted(controller, cancelOn)
	local character = controller.Character
	if not character or not cancelOn then return false end

	return controller.StatusService:CheckStatuses(character, cancelOn)
end

function VisualsCore.WatchInterrupt(controller, settings)
	local watch = { Cancelled = false, Emissions = {}, Connection = nil }

	function watch:Stop()
		if self.Connection then
			self.Connection:Disconnect()
			self.Connection = nil
		end
	end

	local character = controller.Character
	local cancelOn = CancelList({}, settings)

	if not character or not cancelOn then return watch end

	local function cancel()
		if watch.Cancelled then return end
		watch.Cancelled = true
		watch:Stop()

		for _, emission in watch.Emissions do
			emission:Clear()
		end

		table.clear(watch.Emissions)
	end

	watch.Connection = character.AttributeChanged:Connect(function(name)
		if table.find(cancelOn, name) and character:GetAttribute(name) == true then
			cancel()
		end
	end)

	if IsInterrupted(controller, cancelOn) then
		cancel()
	end

	return watch
end

function VisualsCore.Play(events, speed, fps, watch)
	speed = (typeof(speed) == "number" and speed > 0) and speed or 1
	fps = fps or DEFAULT_FPS

	task.spawn(function()
		local began = os.clock()

		table.sort(events, function(a, b)
			return (a.frame or 0) < (b.frame or 0)
		end)

		for _, event in ipairs(events) do
			if typeof(event.run) ~= "function" then continue end

			local at = (event.frame or 0) / fps / speed
			local remaining = at - (os.clock() - began)

			if remaining > 0 then
				task.wait(remaining)
			end

			if watch and watch.Cancelled then return end

			event.run()
		end

		if watch then
			task.delay(DEFAULT_LIFETIME, function()
				watch:Stop()
			end)
		end
	end)
end

function VisualsCore.SpawnEffect(controller, settings, asset, host, spec)
	if not asset or not host then return end

	spec = spec or {}

	local cancelOn = CancelList(spec, settings)
	if IsInterrupted(controller, cancelOn) then return end

	local lifetime = Resolve(spec, settings, "Lifetime", DEFAULT_LIFETIME)
	local emission = nil

	local attack_vfx = controller.EffectService.new({
		Effect = asset,
		EmitDivider = Resolve(spec, settings, "EmitDivider", 1),
		Owner = controller,
		Cancellable = cancelOn ~= nil,
		CancellableWhitelist = cancelOn,
		CancelWindow = lifetime,
		CancelFade = false,
		CancelBack = function()
			if emission then
				emission:Clear()
			end
		end,
	})

	attack_vfx:SetParent(controller.GetPath:ReadPath(Resolve(spec, settings, "Parent", nil)))
	
	local pivot = host:GetPivot()

	if typeof(spec.CFrame) == "CFrame" then
		pivot = pivot * spec.CFrame
	end

	attack_vfx:SetCFrame(pivot)

	if spec.Weld ~= false then
		attack_vfx:Weld(host)
	end

	if Resolve(spec, settings, "SyncPosition", true) ~= false then
		ApplySyncPosition(attack_vfx.Effect, true)
	end

	local forge = controller.ForgeVFX
	local speed = controller.Speed

	if spec.Retime ~= false and typeof(speed) == "number" and speed > 0 and speed ~= 1 then
		forge.retime(speed, attack_vfx.Effect)
	end

	emission = forge.emit(attack_vfx.Effect)
	emission.Finished:finally(function()
		attack_vfx:Destroy()
	end)

	attack_vfx:SetRemoval(lifetime)
end

function VisualsCore.SpawnAttack(controller, settings, comboIndex, root)
	local assets = ReadAssets(controller, settings)
	local asset = assets and FindAsset(assets, settings, comboIndex)

	VisualsCore.SpawnEffect(controller, settings, asset, root, nil)
end

function VisualsCore.SpawnOneShot(controller, settings, spec, root)
	local character = controller.Character
	if not character then return end

	local asset = FindNamedAsset(ReadAssets(controller, settings), spec.Asset)
	if not asset then return end

	local host = root

	if typeof(spec.Attach) == "string" then
		host = character:FindFirstChild(spec.Attach) or character:FindFirstChild(spec.Attach, true) or root
	end

	VisualsCore.SpawnEffect(controller, settings, asset, host, spec)
end

--@ Turns one OneShots entry into timeline events; baseFrame is the swing's own frame, so a spec
--@ naming neither Frame nor Offset lands on the swing it belongs to.
function VisualsCore.CollectOneShots(controller, settings, key, baseFrame, root, events)
	events = events or {}

	if key == nil or not settings.OneShots then return events end

	local entry = settings.OneShots[key]
	if not entry then return events end

	for _, spec in NormalizeShots(entry) do
		table.insert(events, {
			frame = (spec.Frame or baseFrame or 0) + (spec.Offset or 0),
			run = function()
				VisualsCore.SpawnOneShot(controller, settings, spec, root)
			end,
		})
	end

	return events
end

function VisualsCore.ResolveAfterImage(controller, settings, spec)
	local character = controller.Character
	local sourceName = spec.Source or settings.Weapon

	if not character or typeof(sourceName) ~= "string" then return nil end

	if spec.Within ~= nil then
		return FindUnder(FindUnder(character, spec.Within), sourceName)
	end

	return FindUnder(character, sourceName)
end

function VisualsCore.EmitAfterImage(controller, settings, spec, watch)
	local source = VisualsCore.ResolveAfterImage(controller, settings, spec or {})
	if not source then return end

	local emission = controller.ForgeVFX.emit(source)

	if watch then
		table.insert(watch.Emissions, emission)
	end
end

function VisualsCore.Attack(controller, settings)
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	local comboIndex = controller.ComboIndex

	local frame = settings.Frames and settings.Frames[comboIndex]
	if not root or not frame then return end

	local watch = VisualsCore.WatchInterrupt(controller, settings)

	local events = {
		{
			frame = frame,
			run = function()
				VisualsCore.SpawnAttack(controller, settings, comboIndex, root)
			end,
		},
	}

	for _, afterImage in NormalizeAfterImages(settings.AfterImage and settings.AfterImage[comboIndex]) do
		table.insert(events, {
			frame = afterImage.Frame,
			run = function()
				VisualsCore.EmitAfterImage(controller, settings, afterImage, watch)
			end,
		})
	end

	VisualsCore.CollectOneShots(controller, settings, comboIndex, frame, root, events)

	VisualsCore.Play(events, controller.Speed, settings.FPS, watch)
end

function VisualsCore.OneShot(controller, settings)
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local events = VisualsCore.CollectOneShots(controller, settings, controller.Shot, 0, root)
	if #events == 0 then return end

	VisualsCore.Play(events, controller.Speed, settings.FPS, VisualsCore.WatchInterrupt(controller, settings))
end

return VisualsCore
