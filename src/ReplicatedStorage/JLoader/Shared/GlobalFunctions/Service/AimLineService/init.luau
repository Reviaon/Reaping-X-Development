local Config = require("@self/Config")
local Arc = require("@self/Arc")
local Render = require("@self/Render")

local AimLineService = {}

local Line = {}
Line.__index = Line

local styles = {}

function AimLineService.Style(name: string?)
	local key = name or Config.DefaultStyle
	if styles[key] then return styles[key] end

	local module = script.Styles:FindFirstChild(key)

	if not module or not module:IsA("ModuleScript") then
		warn(`[AimLineService] No style "{key}" under AimLineService.Styles; using {Config.DefaultStyle}.`)
		return AimLineService.Style(if key ~= Config.DefaultStyle then Config.DefaultStyle else nil)
	end

	styles[key] = require(module)
	return styles[key]
end

function AimLineService.new(style: (string | { [string]: any })?)
	local resolved = if typeof(style) == "table" then style else AimLineService.Style(style)

	return setmetatable({
		parts = Render.Create(resolved),
		visible = false,
		tracedAt = -math.huge,
	}, Line)
end

function Line:Stale(origin: Vector3, velocity: Vector3, gravity: Vector3, duration: number): boolean
	if not self.visible or os.clock() - self.tracedAt > Config.Refresh then return true end
	if gravity ~= self.gravity or duration ~= self.duration then return true end
	if (origin - self.origin).Magnitude > Config.Retrace.Position then return true end

	return (velocity - self.velocity).Magnitude > Config.Retrace.Velocity
end

function Line:Draw(origin: Vector3, velocity: Vector3, gravity: Vector3, duration: number, options)
	options = options or {}

	local alpha = math.clamp(if typeof(options.alpha) == "number" then options.alpha else 1, 0, 1)

	if alpha <= 0 or duration <= Config.MinDuration then
		self:Hide()
		return
	end

	if self:Stale(origin, velocity, gravity, duration) then
		if options.prepare then
			options.prepare()
		end

		local reach = self.parts.style.Reach
		local limit = if typeof(reach) == "number" then math.min(duration, reach) else duration
		local at, result = Arc.Trace(limit, options.steps or Config.Steps, options.cast or Arc.Caster(origin, velocity, gravity, options.params))

		self.origin, self.velocity, self.gravity, self.duration = origin, velocity, gravity, duration
		self.at, self.result = at, result
		self.tracedAt = os.clock()

		Render.Mark(self.parts, result)
	end

	Render.Place(self.parts, Arc.Bezier(origin, velocity, gravity, self.at))
	Render.Fade(self.parts, alpha)

	if not self.visible then
		self.visible = true
		Render.Show(self.parts, true)
	end
end

function Line:Hide()
	if not self.visible then return end

	self.visible = false
	Render.Show(self.parts, false)
end

function Line:Destroy()
	Render.Destroy(self.parts)
	setmetatable(self, nil)
end

return AimLineService
