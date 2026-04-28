--@ ClientController
--[[
	Modules are cached on first require(), every script
	that accesses GlobalFunctions.ClientController receives the SAME
	table reference - making it a natural shared store across all
	client handlers and components.

	Usage:
		local ClientController = GlobalFunctions.ClientController

		-- Read
		local char = ClientController:Get("Character")

		-- Write
		ClientController:Set("Character", character)

		-- Bulk merge
		ClientController:Update({ Character = character, Humanoid = humanoid })

		-- Remove a key
		ClientController:Remove("CrouchIdle")

		-- Wipe everything (e.g. on character removal)
		ClientController:Reset()
]]

local Players = game:GetService("Players")

local ClientController = {}
ClientController.__index = ClientController

--@ Internal state table - this is the shared mutable array
ClientController.State = {
	--@ Player / Character references (populated by MovementHandler:InitCharacter)
	Player          = nil,
	Character       = nil,
	Humanoid        = nil,
	HumanoidRootPart = nil,

	--@ Animation track handles (set and cleared by components)
	-- e.g. CrouchIdle, SprintTrack, etc.

	--@ Arbitrary component flags / data
	-- Components may freely read and write additional keys here.
}

-- ─────────────────────────────────────────────
--  Core API
-- ─────────────────────────────────────────────

--@ Set a single key on State
function ClientController:Set(key: string, value: any)
	self.State[key] = value
end

--@ Get a single key from State
function ClientController:Get(key: string): any
	return self.State[key]
end

--@ Remove a single key from State
function ClientController:Remove(key: string)
	self.State[key] = nil
end

--@ Merge a table of key/value pairs into State
function ClientController:Update(data: {[string]: any})
	for k, v in pairs(data) do
		self.State[k] = v
	end
end

--@ Wipe all keys (keeps the table reference intact - consumers won't break)
function ClientController:Reset()
	for k in pairs(self.State) do
		self.State[k] = nil
	end
end

-- ─────────────────────────────────────────────
--  Character helpers
-- ─────────────────────────────────────────────

--@ Called once the local character is ready; populates core references
function ClientController:SetCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	self:Update({
		Character  = character,
		Humanoid = humanoid,
		HumanoidRootPart = humanoidRootPart,
		Player   = Players.LocalPlayer,
	})
end

--@ Clear character references on character removal
function ClientController:ClearCharacter()
	self:Update({
		Character = nil,
		Humanoid = nil,
		HumanoidRootPart = nil,
	})
end

return ClientController
