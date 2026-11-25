local Registry = require("./Registry")

local Tracker = {
	Paths = {} :: { [Sound]: string },
	Holders = {} :: { [Sound]: Instance },
}

function Tracker.Forget(Sound: Sound)
	Tracker.Paths[Sound] = nil
	Tracker.Holders[Sound] = nil
end

function Tracker.Release(Sound: Sound)
	local Holder = Tracker.Holders[Sound]
	Tracker.Forget(Sound)

	if Holder then
		Holder:Destroy()
	else
		Sound:Destroy()
	end
end

function Tracker.Add(Sound: Sound, Path: string, Holder: Instance?)
	Tracker.Paths[Sound] = Path
	if Holder then
		Tracker.Holders[Sound] = Holder
	end

	local function Release()
		Tracker.Release(Sound)
	end

	Sound.Ended:Connect(Release)
	Sound.Stopped:Connect(Release)
	Sound.Destroying:Connect(function()
		Tracker.Forget(Sound)
	end)
end

function Tracker.Find(Prefix: string?, Scope: Instance?): { Sound }
	local Found = {}

	for Sound, Path in Tracker.Paths do
		if Registry.Under(Path, Prefix) and (not Scope or Sound:IsDescendantOf(Scope)) then
			table.insert(Found, Sound)
		end
	end
	return Found
end

return Tracker
