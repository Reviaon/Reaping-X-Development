local Telemetry = {}
Telemetry.__index = Telemetry

function Telemetry.new(target: Instance, interval: number)
	return setmetatable({
		Target = target,
		Interval = interval,
		WindowStart = os.clock(),
		Frames = 0,
		StepTotal = 0,
		StepPeak = 0,
		Thinks = 0,
		SpawnTotal = 0,
		Spawns = 0,
	}, Telemetry)
end

function Telemetry:Spawned(seconds: number)
	self.SpawnTotal += seconds
	self.Spawns += 1
end

function Telemetry:Frame(seconds: number, thinks: number, mobs: number)
	self.Frames += 1
	self.StepTotal += seconds
	self.StepPeak = math.max(self.StepPeak, seconds)
	self.Thinks += thinks

	local now = os.clock()
	local elapsed = now - self.WindowStart
	if elapsed < self.Interval then return end

	local target = self.Target

	target:SetAttribute("MobCount", mobs)
	target:SetAttribute("StepMsAvg", self.StepTotal / self.Frames * 1000)
	target:SetAttribute("StepMsPeak", self.StepPeak * 1000)
	target:SetAttribute("ThinksPerSecond", self.Thinks / elapsed)

	if self.Spawns > 0 then
		target:SetAttribute("SpawnMsAvg", self.SpawnTotal / self.Spawns * 1000)
	end

	self.WindowStart = now
	self.Frames = 0
	self.StepTotal = 0
	self.StepPeak = 0
	self.Thinks = 0
	self.SpawnTotal = 0
	self.Spawns = 0
end

return Telemetry
