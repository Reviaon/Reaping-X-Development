local UserInputService = game:GetService("UserInputService")

local Config = require("./Config")
local Types = require("./Types")

type Session = Types.Session
type Action = Types.Action

type Binding = {
	Action: Action,
	Argument: number?,
}

local Input = {}

local actions: { [string]: Action }? = nil

local function loadActions(): { [string]: Action }
	if actions then return actions end

	local loaded: { [string]: Action } = {}
	local folder = script.Parent and script.Parent:FindFirstChild("Actions")

	for _, module in if folder then folder:GetChildren() else {} do
		if module:IsA("ModuleScript") then
			loaded[module.Name] = (require :: any)(module) :: Action
		end
	end

	actions = loaded

	return loaded
end

local function bindingsFor(session: Session): { [Types.Input]: Binding }
	local found = loadActions()
	local bindings: { [Types.Input]: Binding } = {}
	local controls: { [string]: { Types.Input } } = session.Entry.controls or {}
	local shots: { Types.Shot } = session.Entry.shots or {}

	for name, inputs in controls do
		local action = found[name]

		if not action then
			warn(`[MorphHandler] {session.Name} binds "{name}", which has no MorphHandler/Actions module.`)
			continue
		end

		for _, input in inputs do
			bindings[input] = { Action = action }
		end
	end

	for index in shots do
		local key = Config.ShotKeys[index + #session.Profile.abilities]
		local shot = found.Shot

		if key and shot then
			bindings[key] = { Action = shot, Argument = index }
		end
	end

	return bindings
end

function Input.Bind(session: Session)
	local bindings = bindingsFor(session)

	local function find(input: InputObject): Binding?
		return bindings[input.KeyCode] or bindings[input.UserInputType]
	end

	session.Trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() or session.Humanoid.Health <= 0 then return end

		local binding = find(input)
		local began = binding and binding.Action.Began

		if binding and began then
			began(session, binding.Argument)
		end
	end)

	session.Trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		local binding = find(input)
		local ended = binding and binding.Action.Ended

		if binding and ended then
			ended(session, binding.Argument)
		end
	end)

	for _, binding in bindings do
		if binding.Action.Step then
			session.Stepping[binding.Action] = true
		end
	end
end

function Input.Step(session: Session)
	for action in session.Stepping do
		local step = action.Step

		if step then
			step(session)
		end
	end
end

return Input
