--@ Shared engine behind every <Weapon>Visuals module. A weapon module supplies Settings and
--@ delegates; nothing weapon-specific lives here.

local VisualsCore = {}

local DEFAULT_FPS = 60
local DEFAULT_LIFETIME = 3

--@ Imported VFX sets are named Hit{N}; Staff's original set is Attack{N}. Settings.Prefix pins one,
--@ otherwise both are tried so a newly imported weapon works either way.
local DEFAULT_PREFIXES = { "Attack", "Hit" }

local function FindAsset(assets, settings, comboIndex)
	local prefixes = settings.Prefix and { settings.Prefix } or DEFAULT_PREFIXES

	for _, prefix in prefixes do
		local asset = assets:FindFirstChild(prefix .. comboIndex)
		if asset then return asset end
	end

	return nil
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

--@ Clones the combo's asset onto the root and emits it. A missing asset is skipped, so a weapon
--@ whose VFX are not authored yet still swings.
function VisualsCore.SpawnAttack(controller, settings, comboIndex, root)
	local assets = controller.GetPath:ReadPath(settings.Assets)
	local asset = assets and FindAsset(assets, settings, comboIndex)

	if not asset then return end

	local attack_vfx = controller.EffectService.new({
		Effect = asset,
		EmitDivider = settings.EmitDivider or 1,
	})

	attack_vfx:SetParent(controller.GetPath:ReadPath(settings.Parent))

	--@ GetPivot carries the root's orientation as well as its position, so the swing spawns facing
	--@ wherever the character faces; the weld then keeps it rigid to the root.
	attack_vfx:SetCFrame(root:GetPivot())
	attack_vfx:Weld(root)

	--@ Sync before emitting: the emitters read the flag when the emit starts, not after.
	if settings.SyncPosition ~= false then
		ApplySyncPosition(attack_vfx.Effect, true)
	end

	local forge = controller.ForgeVFX
	local speed = controller.Speed

	if typeof(speed) == "number" and speed > 0 and speed ~= 1 then
		forge.retime(speed, attack_vfx.Effect)
	end

	forge.emit(attack_vfx.Effect).Finished:finally(function()
		attack_vfx:Destroy()
	end)

	attack_vfx:SetRemoval(settings.Lifetime or DEFAULT_LIFETIME)
end

--@ Trails off the equipped weapon part itself. Settings.Weapon is the PART name the rig
--@ transplanted, not the weapon id - see ServerController:ApplyRig.
function VisualsCore.EmitAfterImage(controller, settings)
	local character = controller.Character
	local weaponName = settings.Weapon

	if not character or not weaponName then return end

	local weapon = character:FindFirstChild(weaponName)
	if not weapon then return end

	controller.ForgeVFX.emit(weapon)
end

--@ One swing: the combo's afterimage and its attack VFX, each on its own authored frame.
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

	local afterImage = settings.AfterImage and settings.AfterImage[comboIndex]

	if afterImage then
		table.insert(events, {
			frame = afterImage,
			run = function()
				VisualsCore.EmitAfterImage(controller, settings)
			end,
		})
	end

	VisualsCore.Play(events, controller.Speed, settings.FPS)
end

return VisualsCore
