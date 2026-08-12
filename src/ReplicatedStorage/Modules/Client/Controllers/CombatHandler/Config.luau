--@ Combat Config
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Weapon configs are one ModuleScript per weapon under Libraries.WeaponsLibrary.
--@ The module NAME is the weapon id, and must match the Tool's name exactly - that is
--@ what ResolveWeaponId hands back and what the server publishes through the
--@ EquippedWeapon attribute. Read through descendants so weapons can be grouped into
--@ subfolders later without touching this file.
local WeaponsLibrary = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("WeaponsLibrary")

local function BuildWeaponConfig()
	local config = {}

	for _, module in WeaponsLibrary:GetDescendants() do
		if not module:IsA("ModuleScript") then continue end

		--@ One malformed weapon module must not take the whole combat config down with it
		local loaded, data = pcall(require, module)

		if not loaded then
			warn(`[CombatConfig] Weapon module "{module:GetFullName()}" failed to load: {data}`)
			continue
		end

		config[module.Name] = data
	end

	return config
end

local CombatConfig = {
	ComboTimeout = 1.5, --@ Default Combo Time Out
	DefaultMaxCombo = 3, --@ Default Max Combo
	DefaultWeapon = "Melee", --@ Default weapon id to resolve to when no weapon is equipped or specified.
	InputBuffering = false, --@ When true, attack presses blocked by an active attack queue and auto-fire when ready.

	--@ Keyed by weapon id -> that weapon's module under Libraries.WeaponsLibrary.
	WeaponConfig = BuildWeaponConfig(),
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

	--@ Resolve once up front, armed or not, so the idle stance has a name to play from
	--@ the first frame instead of waiting on the next equip/unequip event.
	self:UpdateWeaponConfig(controller)

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

	
	controller.PhysicsService.ClearExistingImpulse(controller)
end

--@ Publishes the name of the idle stance for the currently resolved weapon.
--@ IdleComponent owns playing/stopping the track and swaps itself when this changes,
--@ so this only has to keep the name current.
function CombatConfig:UpdateWeaponConfig(controller)
	local Character = controller.Character
	if not Character then return end

	controller._idle_animation = string.format("%s%s", self:ResolveWeaponId(controller), "Idle")
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
