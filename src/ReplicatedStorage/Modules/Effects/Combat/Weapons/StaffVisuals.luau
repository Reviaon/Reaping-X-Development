local StaffVisuals = {}


StaffVisuals.Settings = {
	Assets = "ReplicatedStorage/Storage/Particles/CombatVFX/Weapons/Staff",
	Parent = "Workspace/World/Visuals",
	Weapon = "Meshes/diamond stafflow",
	
	Lifetime = 3,
	FPS = 60,
	Frames = {[1] = 30, [2] = 28, [3] = 29, [4] = 15, [5] = 25},
	StaffAfterImage = {[1] = 15, [3] = 9}
}

StaffVisuals.Play = function(events, speed)
	speed = (typeof(speed) == "number" and speed > 0) and speed or 1

	task.spawn(function()
		local _began = os.clock()

		table.sort(events, function(a, b)
			return (a.frame or 0) < (b.frame or 0)
		end)

		for _, event in ipairs(events) do
			if typeof(event.run) ~= "function" then continue end

			local _at = (event.frame or 0) / StaffVisuals.Settings.FPS / speed
			local _remaining = _at - (os.clock() - _began)

			if _remaining > 0 then
				task.wait(_remaining)
			end

			event.run()
		end
	end)
end

--@ Handles Combat Visuals For Staff
StaffVisuals.Attack = function(controller)
	local _character = controller.Character

	if not _character then return end

	local _root = _character:FindFirstChild("HumanoidRootPart")
	local _humanoid = _character:FindFirstChildOfClass("Humanoid")
	local _count = controller.ComboIndex
	
	local _frame = StaffVisuals.Settings.Frames[_count]
	local _afterimage = StaffVisuals.Settings.StaffAfterImage[_count]

	if not _root or not _frame then return end
		
	local _events = {
		{
			frame = _afterimage,
			run = function()
				if StaffVisuals.Settings.StaffAfterImage[_count] then
					local _weapon = _character:FindFirstChild(StaffVisuals.Settings.Weapon)
					local _forge = controller.ForgeVFX
					
					if _weapon then
						_forge.emit(_weapon)
					end
				end
			end,
		},
		{
			frame = _frame,
			run = function()
				warn("Creating Attack Visuals For Staff.")
				
				local _assets = controller.GetPath:ReadPath(StaffVisuals.Settings.Assets)
				local _template = _assets and _assets:FindFirstChild("Attack" .. _count)

				if not _template then return end

				local attack_vfx = controller.EffectService.new({
					Effect = _template,
					EmitDivider = 1
				});
				
				attack_vfx:SetParent(controller.GetPath:ReadPath(StaffVisuals.Settings.Parent))
				attack_vfx:SetCFrame(_root:GetPivot())
				attack_vfx:Weld(_root)

				local _forge = controller.ForgeVFX
				local _speed = controller.Speed

				if typeof(_speed) == "number" and _speed > 0 and _speed ~= 1 then
					_forge.retime(_speed, attack_vfx.Effect)
				end

				_forge.emit(attack_vfx.Effect).Finished:finally(function()
					attack_vfx:Destroy()
				end)

				attack_vfx:SetRemoval(StaffVisuals.Settings.Lifetime)
			end,
		},
	}

	StaffVisuals.Play(_events, controller.Speed)
end

return StaffVisuals
