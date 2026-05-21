--@ Combat Config
local CombatConfig = {
	ComboTimeout = 1.5,
	DefaultMaxCombo = 3,
	DefaultWeapon = "Unarmed",

	--@ Configure max combo per weapon id/name.
	WeaponConfig = {
		Unarmed = {
			MaxCombo = 3,
		},
		WoodenSword = {
			MaxCombo = 4
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
		if onChanged then onChanged(child.Name) end
	end)

	trove:Connect(Character.ChildRemoved, function(child)
		if not child:IsA("Tool") then return end
		if controller:Get("EquippedWeapon") == child.Name then
			controller:Remove("EquippedWeapon")
			if onChanged then onChanged(self.DefaultWeapon) end
		end
	end)
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

return CombatConfig
