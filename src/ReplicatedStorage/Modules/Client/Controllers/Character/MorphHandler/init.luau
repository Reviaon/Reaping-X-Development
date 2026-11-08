local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local MorphHandler = Jloader.CreateHandler({ Name = script.Name })
MorphHandler.Morphs = true

local Session = require("@self/Session")
local Types = require("@self/Types")

local current: Types.Session? = nil

function MorphHandler:InitCharacter(controller: any, isLocal: boolean)
	if not isLocal then return end

	local character: Model? = controller.Character

	if current then
		current:Destroy()
		current = nil
	end

	if not character then return end

	local session = Session.new(character)
	if not session then return end

	if Players.LocalPlayer.Character ~= character then
		session:Destroy()
		return
	end

	current = session
	session:Start()
end

function MorphHandler:Current(): Types.Session?
	return current
end

return MorphHandler
