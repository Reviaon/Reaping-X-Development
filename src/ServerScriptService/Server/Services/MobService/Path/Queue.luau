local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Config = require("./Config")

local Queue = {}

local waiting = {}
local pending = {}
local inFlight = 0
local pump = nil

local function pathFor(nav, mob, settings): Path
	if not nav.Path then
		nav.Path = PathfindingService:CreatePath({
			AgentRadius = mob.Body.Radius,
			AgentHeight = settings.agent_height,
			AgentCanJump = settings.can_jump,
			SupportPartialPath = true,
		})
	end

	return nav.Path
end

local function run(request)
	inFlight += 1
	request.Nav.Computing = true

	task.spawn(function()
		local path = pathFor(request.Nav, request.Mob, request.Settings)
		local ok = pcall(path.ComputeAsync, path, request.From, request.Goal)

		inFlight -= 1
		request.Nav.Computing = false

		if request.Mob.Dead or not ok then return end

		local status = path.Status
		local waypoints = if status == Enum.PathStatus.Success or status == Enum.PathStatus.ClosestNoPath then path:GetWaypoints() else nil

		request.Done(status, waypoints, request.Goal)
	end)
end

local function drain()
	while inFlight < Config.MaxInFlight and #waiting > 0 do
		local nav = table.remove(waiting, 1)
		local request = pending[nav]
		pending[nav] = nil

		if request then
			run(request)
		end
	end

	if #waiting == 0 and pump then
		pump:Disconnect()
		pump = nil
	end
end

function Queue.Request(nav, mob, from: Vector3, goal: Vector3, settings, done)
	local request = { Nav = nav, Mob = mob, From = from, Goal = goal, Settings = settings, Done = done }

	if not pending[nav] then
		table.insert(waiting, nav)
	end

	pending[nav] = request

	if not pump then
		pump = RunService.Heartbeat:Connect(drain)
	end
end

function Queue.Busy(nav): boolean
	return nav.Computing == true or pending[nav] ~= nil
end

function Queue.Backlog(): (number, number)
	return #waiting, inFlight
end

return Queue
