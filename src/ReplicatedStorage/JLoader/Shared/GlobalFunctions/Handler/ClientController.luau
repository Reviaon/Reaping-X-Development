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
	Player = nil,
	Character = nil,
	Humanoid = nil,
	HumanoidRootPart = nil,

	--@ Animation track handles (set and cleared by components)
	-- e.g. CrouchIdle, SprintTrack, etc.

	--@ Arbitrary component flags / data
	-- Components may freely read and write additional keys here.
}

function ClientController:Set(key: string, value: any)
	self.State[key] = value
end

function ClientController:Get(key: string): any
	return self.State[key]
end

function ClientController:Remove(key: string)
	self.State[key] = nil
end

function ClientController:Update(data: {[string]: any})
	for k, v in pairs(data) do
		self.State[k] = v
	end
end

function ClientController:Reset()
	for k in pairs(self.State) do
		self.State[k] = nil
	end
end

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

function ClientController:ClearCharacter()
	self:Update({
		Character = nil,
		Humanoid = nil,
		HumanoidRootPart = nil,
	})
end

return setmetatable(ClientController, {
	__index = function(_, key)
		return ClientController.State[key]
	end,
	__newindex = function(_, key, value)
		ClientController.State[key] = value
	end,
})
