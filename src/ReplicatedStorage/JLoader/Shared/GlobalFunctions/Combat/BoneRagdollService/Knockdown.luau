local RunService = game:GetService("RunService")

local Config = require("./Config")
local Build = require("./Build")
local Recover = require("./Recover")

local Knockdown = {}

local definitions = setmetatable({} :: { [Model]: any }, { __mode = "k" })
local tokens = setmetatable({} :: { [Model]: number }, { __mode = "k" })

local function humanoidOf(model: Model): Humanoid?
	return model:FindFirstChildOfClass("Humanoid")
end

local function alive(model: Model): boolean
	local humanoid = humanoidOf(model)
	return model.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function tumble(velocity: Vector3, spin: number?): Vector3
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if typeof(spin) ~= "number" or spin == 0 or horizontal.Magnitude < 1e-3 then return Vector3.zero end

	return Vector3.yAxis:Cross(horizontal.Unit) * math.rad(spin)
end

local function throw(model: Model, velocity: Vector3, spin: number?)
	local folder = model:FindFirstChild(Config.FolderName)
	local angular = tumble(velocity, spin)

	for _, part in folder and folder:GetChildren() or {} do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = velocity
			part.AssemblyAngularVelocity = angular
		end
	end
end

local function holdLimp(model: Model, token: number)
	local record = Build.Records[model]
	if not record then return end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not model.Parent or tokens[model] ~= token or Build.Records[model] ~= record then
			connection:Disconnect()
			return
		end

		for part in record.parts do
			part.CanCollide = false
		end
	end)
end

local function floatAir(model: Model, token: number, gravity: number)
	local record = Build.Records[model]
	local folder = model:FindFirstChild(Config.FolderName)
	local first = record and folder and folder:FindFirstChild(record.first)
	if not first or not first:IsA("BasePart") or gravity >= 1 then return end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }

	local share = 1 - gravity
	local connection

	connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent or tokens[model] ~= token or Build.Records[model] ~= record or not first.Parent then
			connection:Disconnect()
			return
		end

		if first.AssemblyLinearVelocity.Y <= 0 then
			local reach = first.Size.Magnitude / 2 + Config.LandReach

			if workspace:Raycast(first.Position, Vector3.new(0, -reach, 0), params) then
				connection:Disconnect()
				return
			end
		end

		local lift = Vector3.new(0, workspace.Gravity * share * dt, 0)

		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") and not part.Anchored then
				part.AssemblyLinearVelocity += lift
			end
		end
	end)
end

function Knockdown.Register(model: Model, definition)
	definitions[model] = definition
end

function Knockdown.Can(model: Model): boolean
	local definition = definitions[model]
	return definition ~= nil and definition.knockdown == true and alive(model)
end

function Knockdown.Start(model: Model, duration: number, velocity: Vector3, spin: number?, gravity: number?): boolean
	if not Knockdown.Can(model) then return false end
	if not model:HasTag(Config.Tag) and not Build.Body(model, definitions[model]) then return false end

	local humanoid = humanoidOf(model) :: Humanoid
	local token = (tokens[model] or 0) + 1
	tokens[model] = token

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	throw(model, velocity, spin)
	holdLimp(model, token)
	floatAir(model, token, gravity or Config.AirGravity)

	task.delay(duration, function()
		if tokens[model] ~= token then return end
		tokens[model] = nil

		if not alive(model) then return end

		Recover.Body(model)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)

	return true
end

return Knockdown
