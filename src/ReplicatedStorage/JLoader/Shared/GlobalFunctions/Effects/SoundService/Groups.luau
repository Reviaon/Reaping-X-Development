local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require("./Config")

local Groups = {
	Made = {} :: { [string]: SoundGroup },
}

function Groups.Get(Category: string): SoundGroup?
	if not (RunService:IsClient() and RunService:IsRunning()) then
		return nil
	end

	local Existing = Groups.Made[Category]
	if Existing and Existing.Parent then
		return Existing
	end

	local Authored = SoundService:FindFirstChild(Category)
	if Authored and Authored:IsA("SoundGroup") then
		Groups.Made[Category] = Authored
		return Authored
	end

	local Group = Instance.new("SoundGroup")
	Group.Name = Category
	Group.Volume = (Config.Groups :: { [string]: number })[Category] or 1
	Group.Parent = SoundService

	Groups.Made[Category] = Group
	return Group
end

return Groups
