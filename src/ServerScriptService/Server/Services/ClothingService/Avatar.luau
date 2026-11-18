--[[@
	**Avatar**: keeps a player's own Roblox accessories and clothing off their body
	- **Strip:** destroys every child of a `StripClasses` class
	  - Hair is kept: an Accessory of a `KeepTypes` type, or one whose Handle carries a `KeepAttachments` attachment
	- **Guard:** strips now, then again whenever one is added, so an appearance that loads late never shows
	  - The connection dies with the character
]]
local Config = require("./Config")

local Avatar = {}

local function kept(child: Instance): boolean
	if child:IsA("Accessory") and table.find(Config.KeepTypes, child.AccessoryType) then return true end

	local handle = child:IsA("Accoutrement") and child:FindFirstChild("Handle")
	if not handle then return false end

	for _, name in Config.KeepAttachments do
		if handle:FindFirstChild(name) then return true end
	end

	return false
end

local function stripped(child: Instance): boolean
	for _, class in Config.StripClasses do
		if child:IsA(class) then return not kept(child) end
	end

	return false
end

function Avatar.Strip(character: Model)
	for _, child in character:GetChildren() do
		if stripped(child) then
			child:Destroy()
		end
	end
end

function Avatar.Guard(character: Model): RBXScriptConnection
	Avatar.Strip(character)

	return character.ChildAdded:Connect(function(child: Instance)
		if stripped(child) then
			task.defer(child.Destroy, child)
		end
	end)
end

return Avatar
