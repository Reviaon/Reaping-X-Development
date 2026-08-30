--@ Shared engine behind every <Weapon>Visuals module. A weapon module supplies Settings and
--@ delegates; nothing weapon-specific lives here.

local VisualsCore = {}

local DEFAULT_FPS = 60
local DEFAULT_LIFETIME = 3

--@ Imported VFX sets are named Hit{N}; Staff's original set is Attack{N}. Settings.Prefix pins one,
--@ otherwise both are tried so a newly imported weapon works either way.
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

--@ One-shots name their asset outright, so they skip the prefix search a combo swing needs.
local function FindNamedAsset(assets, name)
	if not assets or typeof(name) ~= "string" then return nil end

	return assets:FindFirstChild(name)
end

--@ Settings.OneShots: a [comboIndex] key rides that swing, a ["Name"] key fires on demand via
--@ Method = "OneShot" + Info.Shot. An entry is an asset name, a spec table, or a list of either;
--@ downstream only sees the list form. Spec = Asset (required), Frame, Offset, Attach, CFrame,
--@ Weld, Retime, and SyncPosition/Lifetime/EmitDivider/Parent falling back to Settings.
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

--@ Direct child first so an exact rig part wins, then a descendant sweep so an emitter nested in
--@ a limb or inside the weapon is still reachable.
local function FindUnder(root, name)
	if not root or typeof(name) ~= "string" then return nil end

	return root:FindFirstChild(name) or root:FindFirstChild(name, true)
end

--@ Settings.AfterImage: [comboIndex] = frame, or a spec table, or a list of either. Spec = Frame
--@ (required), Source (emitter name, defaults to Settings.Weapon), Within (character descendant to
--@ search inside, for when a name repeats across limbs).
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

--@ A per-shot override falls back to the weapon's Settings, then to the module default.
local function Resolve(spec, settings, key, default)
	local value = spec[key]
	if value ~= nil then return value end

	value = settings[key]
	if value ~= nil then return value end

	return default
end

--@ Forge freezes an emitter's origin at emit time unless SyncPosition is set, so an effect stays
--@ where it spawned while the character keeps moving. Set on the CLONE, never the imported asset,
--@ so a re-import cannot undo it. Models are the emitter refs; an existing flag is flipped wherever
--@ it sits.
local function ApplySyncPosition(effect: Instance, enabled: boolean)
	for _, descendant in effect:GetDescendants() do
		if descendant:IsA("Model") or descendant:GetAttribute("SyncPosition") ~= nil then
			descendant:SetAttribute("SyncPosition", enabled)
		end
	end
end

--@ Runs frame-keyed events on one timeline. Frames are authored against the animation at 1x, so
--@ dividing by speed keeps every event on its authored frame at any playback multiplier.
function VisualsCore.Play(events, speed, fps)
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

			event.run()
		end
	end)
end

--@ Clones one asset onto a host part and emits it - swings and one-shots both land here, differing
--@ only by spec. A missing asset is skipped, so an unauthored weapon still swings.
function VisualsCore.SpawnEffect(controller, settings, asset, host, spec)
	if not asset or not host then return end

	spec = spec or {}

	local attack_vfx = controller.EffectService.new({
		Effect = asset,
		EmitDivider = Resolve(spec, settings, "EmitDivider", 1),
	})

	attack_vfx:SetParent(controller.GetPath:ReadPath(Resolve(spec, settings, "Parent", nil)))

	--@ GetPivot carries the host's orientation as well as its position, so the visual spawns facing
	--@ wherever the character faces; CFrame nudges it off that pivot without leaving its space.
	local pivot = host:GetPivot()

	if typeof(spec.CFrame) == "CFrame" then
		pivot = pivot * spec.CFrame
	end

	attack_vfx:SetCFrame(pivot)

	--@ Weld = false leaves a shot where it lands; the default is rigid to the host.
	if spec.Weld ~= false then
		attack_vfx:Weld(host)
	end

	--@ Sync before emitting: the emitters read the flag when the emit starts, not after.
	if Resolve(spec, settings, "SyncPosition", true) ~= false then
		ApplySyncPosition(attack_vfx.Effect, true)
	end

	local forge = controller.ForgeVFX
	local speed = controller.Speed

	--@ Retime = false pins a shot to its authored duration instead of scaling with attack speed.
	if spec.Retime ~= false and typeof(speed) == "number" and speed > 0 and speed ~= 1 then
		forge.retime(speed, attack_vfx.Effect)
	end

	forge.emit(attack_vfx.Effect).Finished:finally(function()
		attack_vfx:Destroy()
	end)

	attack_vfx:SetRemoval(Resolve(spec, settings, "Lifetime", DEFAULT_LIFETIME))
end

--@ The combo's own asset, resolved by prefix.
function VisualsCore.SpawnAttack(controller, settings, comboIndex, root)
	local assets = ReadAssets(controller, settings)
	local asset = assets and FindAsset(assets, settings, comboIndex)

	VisualsCore.SpawnEffect(controller, settings, asset, root, nil)
end

--@ Resolves a one-shot's asset and host part, then hands both to the shared spawner.
function VisualsCore.SpawnOneShot(controller, settings, spec, root)
	local character = controller.Character
	if not character then return end

	local asset = FindNamedAsset(ReadAssets(controller, settings), spec.Asset)
	if not asset then return end

	--@ Attach names a character part; without one the shot rides the root like a swing does.
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

--@ A rig authors its afterimage either onto the weapon part it transplants (Settings.Weapon, the
--@ PART name - see ServerController:ApplyRig) or onto a limb, like the Dagger's Spin attachment in
--@ the Right Arm. Source names either; Within pins the container it lives in.
function VisualsCore.ResolveAfterImage(controller, settings, spec)
	local character = controller.Character
	local sourceName = spec.Source or settings.Weapon

	if not character or typeof(sourceName) ~= "string" then return nil end

	--@ A named Within is authoritative: if it is missing the emitter is missing too, rather than
	--@ some same-named instance elsewhere on the character standing in for it.
	if spec.Within ~= nil then
		return FindUnder(FindUnder(character, spec.Within), sourceName)
	end

	return FindUnder(character, sourceName)
end

--@ Trails off whatever the rig authored for this swing.
function VisualsCore.EmitAfterImage(controller, settings, spec)
	local source = VisualsCore.ResolveAfterImage(controller, settings, spec or {})
	if not source then return end

	controller.ForgeVFX.emit(source)
end

--@ One swing: afterimage, attack VFX and any one-shots for that combo, each on its own frame.
function VisualsCore.Attack(controller, settings)
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	local comboIndex = controller.ComboIndex

	local frame = settings.Frames and settings.Frames[comboIndex]
	if not root or not frame then return end

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
				VisualsCore.EmitAfterImage(controller, settings, afterImage)
			end,
		})
	end

	VisualsCore.CollectOneShots(controller, settings, comboIndex, frame, root, events)

	VisualsCore.Play(events, controller.Speed, settings.FPS)
end

--@ A named one-shot on its own timeline, for visuals not tied to a swing.
function VisualsCore.OneShot(controller, settings)
	local character = controller.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local events = VisualsCore.CollectOneShots(controller, settings, controller.Shot, 0, root)
	if #events == 0 then return end

	VisualsCore.Play(events, controller.Speed, settings.FPS)
end

return VisualsCore
