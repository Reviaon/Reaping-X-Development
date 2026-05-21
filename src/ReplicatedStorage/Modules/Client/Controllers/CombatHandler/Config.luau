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
		Longsword = {
			MaxCombo = 4,
		},
		DualDaggers = {
			MaxCombo = 5,
		},
		WoodenSword = {
			
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
