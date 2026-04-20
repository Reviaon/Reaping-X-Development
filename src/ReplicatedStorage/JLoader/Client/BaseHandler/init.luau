local Handler = {}

local Shared = script.Parent.Parent.Shared

local GlobalFunctions = require(Shared.GlobalFunctions)
local Signal = GlobalFunctions.Signal

--@ Create a new handler instance with the provided template
Handler.new = function(template)
	local self = setmetatable(template, {__index = Handler})

	--@ Set the priority and signals from the template
	self.Priority = template.Priority or 1
	self.Signals = template.Signals or {}

	--@ Create a folder for the handler within the shared parent
	local Folder = Instance.new("Folder", Shared.Parent.Handlers)
	Folder.Name = self.Name
	self.Folder = Folder

	--@ Initialize signals for the handler
	for _, Name in ipairs(self.Signals) do
		self[Name] = Signal.new()
	end

	return self
end

return Handler