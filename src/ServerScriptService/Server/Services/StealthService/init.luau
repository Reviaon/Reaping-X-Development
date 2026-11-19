--[[@
	**StealthService**: tells mobs who is sneaking
	- **Report:** the client's crouch fires `ReportSneak(true/false)`; the server sets `Config.Attribute` on the character
	  - Its own attribute, not `IsCrouching`: that status is the client's and drives its walk speed, so the server never writes it
	  - A new body starts unflagged, so death and respawn clear it
	- **Read by mobs** (`MobService/Senses/Sight`): a sneaking player is only noticed within the mob's `sneak.notice`; further off it only confuses them, and attacking them still provokes
]]
local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("@self/Config")

local StealthService = Jloader.CreateService({
	Name = script.Name,
	Signals = { Remote = { "ReportSneak" } },
})

function StealthService.Sneaking(character: Model?): boolean
	return character ~= nil and character:GetAttribute(Config.Attribute) == true
end

function StealthService:SetSneaking(character: Model, sneaking: boolean)
	character:SetAttribute(Config.Attribute, if sneaking then true else nil)
end

function StealthService:Init()
	self.ReportSneak:Connect(function(player: Player, sneaking: unknown)
		if typeof(sneaking) ~= "boolean" then return end

		local character = player.Character
		if not character or not character:FindFirstChildOfClass("Humanoid") then return end

		self:SetSneaking(character, sneaking)
	end)
end

return StealthService
