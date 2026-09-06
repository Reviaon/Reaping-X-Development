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

--@ Visuals are built and played on clients only; the relay hands one request to the
--@ server, which fans it back out so every client renders the same hit.
local visualRelay = nil

local function getVisualRelay()
	visualRelay = visualRelay or Jloader.GetService("EffectService")
	return visualRelay
end

local combatRelay = nil

local function getCombatRelay()
	combatRelay = combatRelay or Jloader.GetService("CombatService")
	return combatRelay
end

--@ Components
CombatHandler.components = {}
CombatHandler.Trove = GarbageCollection.new()
local SCOPE = "Combat"

function CombatHandler:StateFor(controller)
	local state = controller:Scope(SCOPE)

	if state.CurrentBranch == nil then
		state.CurrentBranch = "Neutral"
		state.QueuedBranch = nil
		state.ComboIndex = 0
		state.LastAttackAt = 0
		state.ActiveWeapon = CombatConfig.DefaultWeapon
	end

	return state
end

CombatHandler.components = Jloader.GlobalFunctions.Components.Load(script)

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
	CombatHandler.Trove:Destroy()
	CombatHandler.Trove = GarbageCollection.new()
	CombatHandler:ResetBranchState(controller)

	CombatHandler:StateFor(controller).ActiveWeapon = CombatHandler:ResolveActiveWeapon(controller)

	--@ Components resolve through the controller, so the config has to be on it before
	--@ any of them initialise.
	controller.CombatConfig = CombatConfig

	for _, component in CombatHandler.components do
		if typeof(component.Init) == "function" then
			component:Init(controller)
		end
	end

	local Character = controller.Character
	if not Character then return end

	controller.VisualRelay = getVisualRelay()
	controller.CombatRelay = getCombatRelay()

	CombatHandler.Trove:Connect(RunService.Heartbeat, function()
		CombatHandler:UpdateComboTimeout(controller)
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

		CombatHandler:StateFor(controller).ActiveWeapon = weaponId

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
			CombatHandler:QueueBranch(controller, branchName)
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

	CombatHandler:StateFor(controller).ActiveWeapon = CombatHandler:ResolveActiveWeapon(controller)

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

	local state = CombatHandler:StateFor(controller)

	if typeof(component.CanActivate) == "function" and not component:CanActivate(controller, state) then
		return
	end

	CombatHandler:SetCurrentBranch(controller, branchName)

	if typeof(component.Activate) == "function" then
		component:Activate(controller, state)
	end
end

function CombatHandler:QueueBranch(controller, branchName: string)
	CombatHandler:StateFor(controller).QueuedBranch = branchName
end

function CombatHandler:ConsumeQueuedBranch(controller)
	local state = CombatHandler:StateFor(controller)
	local queuedBranch = state.QueuedBranch
	if not queuedBranch then
		return
	end

	if not CombatHandler:CanBeginBranch(controller, queuedBranch) then
		return
	end

	state.QueuedBranch = nil
	CombatHandler:BeginBranch(controller, queuedBranch)
end

function CombatHandler:SetCurrentBranch(controller, branchName: string)
	local state = CombatHandler:StateFor(controller)

	state.CurrentBranch = branchName
	state.LastAttackAt = os.clock()

	if branchName == "Light" then
		local maxCombo = CombatHandler:GetMaxCombo(controller)
		state.ComboIndex = (state.ComboIndex % maxCombo) + 1
	else
		state.ComboIndex = 0
	end
end

function CombatHandler:GetMaxCombo(controller): number
	local weaponId = CombatHandler:StateFor(controller).ActiveWeapon
	return CombatConfig:GetMaxComboForWeapon(weaponId)
end

function CombatHandler:ResolveActiveWeapon(controller): string
	return CombatConfig:ResolveWeaponId(controller)
end

function CombatHandler:UpdateComboTimeout(controller)
	local state = CombatHandler:StateFor(controller)

	if state.ComboIndex <= 0 then
		return
	end

	if os.clock() - state.LastAttackAt >= CombatConfig.ComboTimeout then
		state.ComboIndex = 0
		state.CurrentBranch = "Neutral"
	end
end

function CombatHandler:ResetBranchState(controller)
	local state = CombatHandler:StateFor(controller)

	state.CurrentBranch = "Neutral"
	state.QueuedBranch = nil
	state.ComboIndex = 0
	state.LastAttackAt = 0
	state.ActiveWeapon = CombatConfig.DefaultWeapon
end

function CombatHandler:StartBlock(controller)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.Activate) == "function" then
		blockComponent:Activate(controller, CombatHandler:StateFor(controller))
	end
end

function CombatHandler:StopBlock(controller)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.Deactivate) == "function" then
		blockComponent:Deactivate(controller, CombatHandler:StateFor(controller))
	end
end

function CombatHandler:Clean()
	InputHandler.Clear(inputConnections)
	CombatHandler.Trove:Destroy()
end

return CombatHandler