--@ Combat Handler
local Jloader = require("@game/ReplicatedStorage/JLoader")
local CombatHandler = Jloader.CreateHandler({ Name = script.Name })

--@ Services
local RunService = game:GetService("RunService")

--@ Imports
local GlobalFunctions = Jloader.GlobalFunctions
local InputHandler = GlobalFunctions.InputHandler
local GarbageCollection = GlobalFunctions.Trove
local ClientController = GlobalFunctions.ClientController
local CombatConfig = require("@self/Config")

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

local blockRelay = nil
local guardConnection = nil

local function getBlockRelay()
	blockRelay = blockRelay or Jloader.GetService("BlockService")
	return blockRelay
end

local rangedRelay = nil
local shotConnection = nil

local function getRangedRelay()
	rangedRelay = rangedRelay or Jloader.GetService("RangedService")
	return rangedRelay
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
		[Enum.UserInputType.MouseButton2] = {
			canHold = false,
			action = function(controller)
				if CombatHandler:CancelProjectile(controller) then return end

				if controller and controller.StatusService:CheckStatuses(controller.Character, { ShiftLock = true }) then 
					CombatHandler:TryPush(controller)
				end
			end,
		},
		[Enum.KeyCode.R] = {
			canHold = false,
			action = function(controller)
				CombatHandler:TryHeavyAttack(controller)
			end,
		},
		--@ Held: the guard goes back up by itself once whatever dropped or refused it has passed.
		[Enum.KeyCode.F] = {
			canHold = true,
			action = function(controller)
				CombatHandler:StartBlock(controller)
			end,
		},
	},
	Ended = {
		[Enum.UserInputType.MouseButton1] = {
			canHold = false,
			action = function(controller)
				CombatHandler:ReleaseProjectile(controller)
			end,
		},
		[Enum.KeyCode.F] = {
			canHold = false,
			action = function(controller)
				CombatHandler:StopBlock(controller, true)
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
	controller.BlockRelay = getBlockRelay()
	controller.RangedRelay = getRangedRelay()

	if not shotConnection and controller.RangedRelay then
		shotConnection = controller.RangedRelay.Shot:Connect(function(shooter, weaponId, origin, direction, firedAt)
			local projectile = CombatHandler.components["ProjectileAttackComponent"]

			if projectile then
				projectile:ObserveShot(ClientController, shooter, weaponId, origin, direction, firedAt)
			end
		end)
	end

	--@ Once, here rather than in Init: the service lookup can come back empty while the server is
	--@ still starting, and a nil there aborted the whole client load.
	if not guardConnection and controller.BlockRelay then
		guardConnection = controller.BlockRelay.Guard:Connect(function(event)
			CombatHandler:OnGuard(ClientController, event)
		end)
	end

	CombatHandler.Trove:Connect(RunService.Heartbeat, function()
		CombatHandler:UpdateComboTimeout(controller)
		CombatHandler:ConsumeQueuedBranch(controller)
	end)

	CombatHandler.Trove:Connect(Character.AncestryChanged, function()
		if not Character:IsDescendantOf(game) and controller.Character == Character then
			controller:ClearCharacter()
		end
	end)

	local interrupted = false
	local inScene = false

	CombatHandler.Trove:Connect(Character.AttributeChanged, function()
		local yielded = controller.StatusService:IsHitYielded(Character)

		if yielded and not interrupted then
			CombatHandler:Interrupt(controller)
			CombatHandler:StopBlock(controller)
		end

		interrupted = yielded

		local scened = controller.PairSceneService.IsInScene(Character)

		if scened and not inScene then
			local branch = CombatHandler.components[CombatHandler:StateFor(controller).CurrentBranch .. "AttackComponent"]

			if not (branch and branch.KeepsScene) then
				CombatHandler:Interrupt(controller)
			end

			CombatHandler:StopBlock(controller)
		end

		inScene = scened
	end)

	CombatConfig:WeaponListener(controller, CombatHandler.Trove, function(weaponId)
		if controller.StatusService:CheckStatuses(Character, { IsAttacking = true })
			or CombatHandler:StateFor(controller).CurrentBranch == "Projectile" then
			CombatHandler:Interrupt(controller)
		end

		CombatConfig:ClearImpulse(controller)

		controller.AnimatorService:StopAllWithReference(
			Character,
			"Attack%d+$"
		)

		CombatHandler:StateFor(controller).ActiveWeapon = weaponId
		CombatHandler:RefreshBlock(controller)

		warn("Active weapon changed to:", weaponId)
	end)
end

function CombatHandler:TryLightAttack(controller)
	if CombatConfig:ResolveWeaponConfig(controller).projectile then
		CombatHandler:TryProjectile(controller)
		return
	end

	CombatHandler:TryAttackBranch(controller, "Light")
end

function CombatHandler:TryProjectile(controller)
	local state = CombatHandler:StateFor(controller)
	local component = CombatHandler.components["ProjectileAttackComponent"]

	if component and state.CurrentBranch == "Projectile" then
		component:Press(controller, state)
		return
	end

	CombatHandler:TryAttackBranch(controller, "Projectile")
end

function CombatHandler:ReleaseProjectile(controller)
	local component = CombatHandler.components["ProjectileAttackComponent"]

	if component then
		component:Release(controller, CombatHandler:StateFor(controller))
	end
end

function CombatHandler:CancelProjectile(controller): boolean
	local state = CombatHandler:StateFor(controller)
	local component = CombatHandler.components["ProjectileAttackComponent"]

	return component ~= nil and state.CurrentBranch == "Projectile" and component:Cancel(controller, state)
end

function CombatHandler:TryHeavyAttack(controller)
	CombatHandler:TryAttackBranch(controller, "Heavy")
end

function CombatHandler:TryPush(controller)
	local tackle = CombatHandler.components["TackleAttackComponent"]

	CombatHandler:TryAttackBranch(controller, if tackle and tackle:IsArmed(controller) then "Tackle" else "Push")
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

	if controller.StatusService:IsHitYielded(Character) or controller.StatusService:IsActionLocked(Character) then
		return false
	end

	if controller.StatusService:CheckStatuses(Character, { IsAttacking = true }) then
		return false
	end

	if CombatHandler:StateFor(controller).CurrentBranch == "Projectile" and branchName ~= "Projectile" then
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

function CombatHandler:Interrupt(controller)
	local state = CombatHandler:StateFor(controller)
	local component = CombatHandler.components[state.CurrentBranch .. "AttackComponent"]

	if component and typeof(component.Deactivate) == "function" then
		component:Deactivate(controller, state)
	end

	CombatConfig:ClearImpulse(controller)

	if controller.Character then
		controller.StatusService:RemoveStatus(controller.Character, "IsAttacking")
	end

	state.QueuedBranch = nil
	state.ComboIndex = 0
	state.CurrentBranch = "Neutral"
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

function CombatHandler:StopBlock(controller, released: boolean?)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.Deactivate) == "function" then
		blockComponent:Deactivate(controller, CombatHandler:StateFor(controller), released)
	end
end

function CombatHandler:RefreshBlock(controller)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.Refresh) == "function" then
		blockComponent:Refresh(controller)
	end
end

function CombatHandler:OnGuard(controller, event)
	local blockComponent = CombatHandler.components["BlockComponent"]
	if blockComponent and typeof(blockComponent.OnGuard) == "function" then
		blockComponent:OnGuard(controller, event)
	end
end

function CombatHandler:Clean()
	InputHandler.Clear(inputConnections)
	CombatHandler.Trove:Destroy()
end

return CombatHandler
