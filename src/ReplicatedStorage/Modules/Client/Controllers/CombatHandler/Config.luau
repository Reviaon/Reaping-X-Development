--@ Combat Config
local CombatConfig = {
	ComboTimeout = 1.5, --@ Default Combo Time Out
	DefaultMaxCombo = 3, --@ Default Max Combo
	DefaultWeapon = "Melee", --@ Default weapon id to resolve to when no weapon is equipped or specified.

	--@ Configure max combo per weapon id/name.

	--@ This Configuration WILL not handle data the server will need to know, such as damage values, hitbox sizes, etc. 
	--@ This is purely for client visual and combo handling purposes.
	WeaponConfig = {
		Melee = {
			MaxCombo = 6,

			attack_cooldown = 0.5,
			attack_cooldown_final = 1,

			attack_duration = {
				0.63,
				0.56,
				0.76,
				0.583,
				0.583,
				0.833
			},

			light_impulse = {
				speed = 10,
				duration = 0.8,
				falloff = 0.5,

				impulse_delay = { --@ When to apply the impulse after the attack has started (useful for syncing with animation events)
					0.35,
					0.217,
					0.35,
					0.267,
					0.25,
					0.533
				}
			}
		},

		WoodenSword = {
			MaxCombo = 4,

			attack_cooldown = .5,
			attack_cooldown_final = 2,

			attack_duration = {
				0.733,
				0.850,
				0.750,
				2
			},

			light_impulse = {
				impulse = {
					{ speed = 10, duration = 0.8, falloff = 0.5 },
					{ speed = 10, duration = 0.8, falloff = 0.5 },
					{ speed = 10, duration = 0.8, falloff = 0.5 },
					{ speed = 10, duration = 2, falloff = 1.5 },
				},
				impulse_delay = { --@ When to apply the impulse after the attack has started (useful for syncing with animation events)
					0.45,
					0.550,
					0.383,
					0.25
				}
			}
		}
	},
}

function CombatConfig:GetMaxComboForWeapon(weaponId: string): number
	local weaponData = self.WeaponConfig[weaponId]
	if weaponData and weaponData.MaxCombo then
		return weaponData.MaxCombo
	end

	return self.DefaultMaxCombo
end

function CombatConfig:WeaponListener(controller, trove, onChanged: (weaponId: string) -> ())
	local Character = controller.Character
	if not Character then return end

	local existing = Character:FindFirstChildOfClass("Tool")
	if existing and self.WeaponConfig[existing.Name] then
		controller:Set("EquippedWeapon", existing.Name)
		if onChanged then onChanged(existing.Name) end
	end

	trove:Connect(Character.ChildAdded, function(child)
		if not child:IsA("Tool") then return end
		if not self.WeaponConfig[child.Name] then
			warn("[CombatConfig] Tool '" .. child.Name .. "' has no WeaponConfig entry, ignoring.")
			return
		end

		controller:Set("EquippedWeapon", child.Name)
		self:UpdateWeaponConfig(controller)

		if onChanged then onChanged(child.Name) end
	end)

	trove:Connect(Character.ChildRemoved, function(child)
		if not child:IsA("Tool") then return end
		if controller:Get("EquippedWeapon") == child.Name then
			controller:Remove("EquippedWeapon")

			self:UpdateWeaponConfig(controller)

			if onChanged then onChanged(self.DefaultWeapon) end
		end
	end)
end

function CombatConfig:ClearImpulse(controller)
	--@ Cancel a pending impulse delay thread before it fires
	local thread = controller:Get("_impulseThread")
	if thread then
		task.cancel(thread)
		controller:Remove("_impulseThread")
	end

	local trove = controller:Get("_activeImpulseTrove")
	
	if trove then
		trove:Destroy()
		controller:Remove("_activeImpulseTrove")
	end

	--@ Fallback: remove the BodyVelocity directly if it somehow outlived the trove
	controller.PhysicsService.ClearExistingImpulse(controller)
end

function CombatConfig:UpdateWeaponConfig(controller)
	local Character = controller.Character
	if not Character then return end

	local weaponId = self:ResolveWeaponId(controller)
	local weaponConfig = self.WeaponConfig[weaponId]

	--@ Play weapon idle animation (add per-weapon idle names below as needed)
	if not controller._idle_animation then
		controller._idle_animation = string.format("%s%s", weaponId, "Idle")

	else

		controller.AnimatorService:StopAllWithReference(
			Character, 
			controller._idle_animation
		)

		controller._idle_animation = string.format("%s%s", weaponId, "Idle")
	end
end

function CombatConfig:ResolveWeaponId(controller): string
	local explicitWeapon = controller:Get("EquippedWeapon")
		or controller:Get("Weapon")
		or controller:Get("WeaponType")

	if typeof(explicitWeapon) == "string" and explicitWeapon ~= "" then
		return explicitWeapon
	end

	local Character = controller.Character
	if Character then
		local attrWeapon = Character:GetAttribute("EquippedWeapon")
			or Character:GetAttribute("Weapon")
			or Character:GetAttribute("WeaponType")

		if typeof(attrWeapon) == "string" and attrWeapon ~= "" then
			return attrWeapon
		end

		local equippedTool = Character:FindFirstChildOfClass("Tool")
		if equippedTool then
			return equippedTool.Name
		end
	end

	return self.DefaultWeapon
end

function CombatConfig:ResolveWeaponConfig(controller)
	local weaponId = self:ResolveWeaponId(controller)

	return self.WeaponConfig[weaponId] or {}
end

return CombatConfig
