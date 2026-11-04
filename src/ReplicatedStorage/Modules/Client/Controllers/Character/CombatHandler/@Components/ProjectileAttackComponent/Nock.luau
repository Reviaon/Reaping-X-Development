local Config = require("./Config")

local Nock = {}

local function pieceOf(Character: Model, state, part: string): BasePart?
	local piece = state.piece

	if piece and piece.Parent == Character and piece:FindFirstChild(part) then return piece end

	state.piece = nil

	for _, child in Character:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("RigPart") and child:FindFirstChild(part) then
			state.piece = child
			return child
		end
	end

	return nil
end

local function weldFor(state, piece: BasePart, arrow: BasePart, offset: CFrame): Weld
	local weld = state.weld
	if weld and weld.Parent == arrow then return weld end

	for _, child in piece:GetChildren() do
		if child:IsA("WeldConstraint") and child.Part1 == arrow then
			child.Enabled = false
			state.heldWeld = child
		end
	end

	weld = Instance.new("Weld")
	weld.Name = Config.NockWeld
	weld.Part0 = piece
	weld.Part1 = arrow
	weld.C0 = offset
	weld.Parent = arrow

	state.weld = weld

	return weld
end

function Nock.Arrow(state, projectile): BasePart?
	local nock = projectile.nock
	local arrow = state.piece and typeof(nock) == "table" and state.piece:FindFirstChild(nock.part or "")

	return if arrow and arrow:IsA("BasePart") then arrow else nil
end

function Nock.Update(Character: Model, state, projectile)
	local nock = projectile.nock
	if typeof(nock) ~= "table" or typeof(nock.part) ~= "string" then return end

	local piece = pieceOf(Character, state, nock.part)
	if not piece then return end

	local arrow = piece:FindFirstChild(nock.part)
	local idle = piece:FindFirstChild(nock.idle or "")
	local aim = piece:FindFirstChild(nock.aim or "") or idle
	if not arrow or not arrow:IsA("BasePart") or not idle or not idle:IsA("Attachment") then return end

	local reload = nock.reload and Character:FindFirstChild(nock.reload, true)
	local weld = weldFor(state, piece, arrow, idle.CFrame)

	local host, offset, visible = piece, idle.CFrame, state.nocked
	local progress = if state.phase == "Idle" then 0 else math.clamp((os.clock() - state.phaseStart) / state.clipLength, 0, 1)

	if state.phase == "Drawing" then
		offset, visible = idle.CFrame:Lerp(aim.CFrame, progress), true
	elseif state.phase == "Holding" then
		offset, visible = aim.CFrame, true
	elseif state.phase == "Firing" then
		offset, visible = aim.CFrame, not state.released
	elseif state.phase == "Reloading" then
		visible = if state.nockMarked ~= nil then state.nockMarked else progress >= (nock.reappear_at or 0)

		if reload and reload:IsA("Attachment") and reload.Parent:IsA("BasePart") then
			host, offset = reload.Parent, reload.CFrame
		end
	end

	if weld.Part0 ~= host then
		weld.Part0 = host
	end

	weld.C0 = offset
	arrow.LocalTransparencyModifier = if visible then 0 else 1
end

function Nock.Reset(state)
	if state.weld then
		state.weld:Destroy()
	end

	if state.heldWeld and state.heldWeld.Parent then
		state.heldWeld.Enabled = true
	end

	state.piece = nil
	state.weld = nil
	state.heldWeld = nil
end

return Nock
