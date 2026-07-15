--@ Combat Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local CombatHandler = Jloader.CreateHandler({ Name = script.Name })

--@ Services
local RunService = game:GetService("RunService")

--@ Imports
local GlobalFunctions = Jloader.GlobalFunctions
local InputHandler = GlobalFunctions.InputHandler
local GarbageCollection = GlobalFunctions.Trove
local ClientController = GlobalFunctions.ClientController
local CombatConfig = require(script:WaitForChild("Config"))

--@ Components
CombatHandler.components = {}
CombatHandler.Trove = GarbageCollection.new()
CombatHandler.State = {
	CurrentBranch = "Neutral",
	QueuedBranch = nil,
	ComboIndex = 0,
	LastAttackAt = 0,
	ActiveWeapon = CombatConfig.DefaultWeapon,
}

for _, component: ModuleScript in script:GetDescendants() do
	if component:IsA("ModuleScript") and not component:GetAttribute("AutoInit") then
		CombatHandler.components[component.Name] = require(component)
	end
end

local inputConnections = {}

local inputActions = {
	Began = {
		[Enum.UserInputType.MouseButton1] = {
			canHold = true,
			action = function(controller)
				CombatHandler:TryLightAttack(controller)
			end,
		},
		[Enum.KeyCode.R] = {
			canHold = false,
			action = function(controller)
				CombatHandler:TryHeavyAttack(controller)
			end,
		},
		[Enum.KeyCode.F] = {
			canHold = false,
			action = function(controller)
				CombatHandler:StartBlock(controller)
			end,
		},
	},
	Ended = {
		[Enum.UserInputType.MouseButton1] = {
			canHold = false,
			action = function(controller)
			end,
		},
		[Enum.KeyCode.F] = {
			canHold = false,
			action = function(controller)
				CombatHandler:StopBlock(controller)
			end,
		},
	},
}

function CombatHandler:Init()
	InputHandler.Init()
	InputHandler.BindInput(inputActions, inputConnections, ClientController)
end

function CombatHandler:InitCharacter(controller)
	warn("Initializing CombatHandler for character:", controller.Character and controller.Character.Name or "nil")

	CombatHandler.Trove:Destroy()
	CombatHandler.Trove = GarbageCollection.new()
	CombatHandler:ResetBranchState()

	CombatHandler.State.ActiveWeapon = CombatHandler:ResolveActiveWeapon(controller)

	for _, component in CombatHandler.components do
		if typeof(component.Init) == "function" then
			component:Init(controller)
		end
	end

	local Character = controller.Character
	if not Character then return end

	controller.CombatConfig = CombatConfig

	CombatHandler.Trove:Connect(RunService.Heartbeat, function()
		CombatHandler:UpdateComboTimeout()
		CombatHandler:ConsumeQueuedBranch(controller)
	end)

	CombatHandler.Trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) then
			controller:ClearCharacter()
		end
	end)

	CombatConfig:WeaponListener(controller, CombatHandler.Trove, function(weaponId)
		CombatConfig:ClearImpulse(controller)

		controller.AnimatorService:StopAllWithReference(
			Character, 
			"Attack"
		)

		CombatHandler.State.ActiveWeapon = weaponId

		warn("Active weapon changed to:", weaponId)
	end)
end

function CombatHandler:TryLightAttack(controller)
	CombatHandler:TryAttackBranch(controller, "Light")
end

function CombatHandler:TryHeavyAttack(controller)
	CombatHandler:TryAttackBranch(controller, "Heavy")
end

function CombatHandler:TryAttackBranch(controller, branchName: string)
	if not CombatHandler:CanBeginBranch(controller, branchName) then
		--@ Presses that land while an attack is still processing are dropped
		--  unless input buffering is explicitly enabled for combat; otherwise a
		--  blocked press silently queues and fires later on its own.
		if CombatConfig.InputBuffering then
			CombatHandler:QueueBranch(branchName)
		end
		return
	end

	CombatHandler:BeginBranch(controller, branchName)
end

function CombatHandler:CanBeginBranch(controller, branchName: string): boolean
	local Character = controller.Character
	if not Character then
		return false
	end

	CombatHandler.State.ActiveWeapon = CombatHandler:ResolveActiveWeapon(controller)

	if controller.StatusService:CheckStatuses(Character, { IsStunned = true }) then
		return false
	end

	if controller.StatusService:CheckStatuses(Character, { IsAttacking = true }) then
		return false
	end

	return branchName ~= ""
end

function CombatHandler:BeginBranch(controller, branchName: string)
	local componentName = branchName .. "AttackComponent"
	local component = CombatHandler.components[componentName]
	if not component then
		warn("[CombatHandler] Missing component:", componentName)
		return
	end

	if typeof(component.CanActivate) == "function" and not component:CanActivate(controller, CombatHandler.State) then
		return
	end

	CombatHandler:SetCurrentBranch(branchName)

	if typeof(component.Activate) == "function" then
		component:Activate(controller, CombatHandler.State)
	end
end

function CombatHandler:QueueBranch(branchName: string)
	CombatHandler.State.QueuedBranch = branchName
end

function CombatHandler:ConsumeQueuedBranch(controller)
	local queuedBranch = CombatHandler.State.QueuedBranch
	if not queuedBranch then
		return
	end

	if not CombatHandler:CanBeginBranch(controller, queuedBranch) then
		return
	end

	CombatHandler.State.QueuedBranch = nil
	CombatHandler:BeginBranch(controller, queuedBranch)
end

function CombatHandler:SetCurrentBranch(branchName: string)
	CombatHandler.State.CurrentBranch = branchName
	CombatHandler.State.LastAttackAt = os.clock()

	if branchName == "Light" then
		local maxCombo = CombatHandler:GetMaxCombo()
		CombatHandler.State.ComboIndex = (CombatHandler.State.ComboIndex % maxCombo) + 1
	else
		CombatHandler.State.ComboIndex = 0
	end
end

function CombatHandler:GetMaxCombo(): number
	local weaponId = CombatHandler.State.ActiveWeapon
	return CombatConfig:GetMaxComboForWeapon(weaponId)
end

function CombatHandler:ResolveActiveWeapon(controller): string
	return CombatConfig:ResolveWeaponId(controller)
end

function CombatHandler:UpdateComboTimeout()
	if CombatHandler.State.ComboIndex <= 0 then
		return
	end

	if os.clock() - CombatHandler.State.LastAttackAt >= CombatConfig.ComboTimeout then
		warn("Combo timeout reached, resetting combo index.")

		CombatHandler.State.ComboIndex = 0
		CombatHandler.State.CurrentBranch = "Neutral"
	end
end

function CombatHandler:ResetBranchState()
	CombatHandler.State.CurrentBranch = "Neutral"
	CombatHandler.State.QueuedBranch = nil
	CombatHandler.State.ComboIndex = 0
	CombatHandler.State.LastAttackAt = 0
	CombatHandler.State.ActiveWeapon = CombatConfig.DefaultWeapon
end

function CombatHandler:StartBlock(controller)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.Activate) == "function" then
		blockComponent:Activate(controller, CombatHandler.State)
	end
end

function CombatHandler:StopBlock(controller)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.Deactivate) == "function" then
		blockComponent:Deactivate(controller, CombatHandler.State)
	end
end

function CombatHandler:Clean()
	InputHandler.Clear(inputConnections)
	CombatHandler.Trove:Destroy()
	CombatHandler:ResetBranchState()
end

return CombatHandler