local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local KonsoleHandler = Jloader.CreateHandler({ Name = script.Name })

local Players = game:GetService("Players")

local Konsole = require(ReplicatedStorage:WaitForChild("Utilities"):WaitForChild("Konsole"))

KonsoleHandler.Settings = {
	--@ What opens it. Konsole's own default is T, which this game already binds, so it is replaced
	--@ rather than added to. Neither of these is spoken for: KeybindsLibrary whitelists WASD, Q, E, R,
	--@ F, C, Space, LeftShift and LeftControl, and names neither of them.
	ActivationKeys = { Enum.KeyCode.Semicolon, Enum.KeyCode.F2 },

	--@ The console frees the mouse while it is open, and gives it back on close. The game drives the
	--@ mouse itself through CameraHandler, so this is stated rather than left to chance.
	UnlocksMouse = true,

	--@ Bottom RIGHT rather than the library's centred default. Nothing occupies that corner today, and
	--@ keeping the centre clear leaves it free for the combat UI this game will grow into.
	--@
	--@ Presets are br / bl / bc / tr / tl / tc, or a UDim2 for somewhere of your own choosing.
	Position = "br",
}

function KonsoleHandler:Load()
	local settings = self.Settings

	local player = Players.LocalPlayer
	if not player:FindFirstChildOfClass("PlayerGui") then
		player:WaitForChild("PlayerGui", 30)
	end

	Konsole.Config.groups.panel.position = settings.Position

	Konsole.setActivationKeys(settings.ActivationKeys)
	Konsole.setActivationUnlocksMouse(settings.UnlocksMouse)

	Konsole.hide()
end

function KonsoleHandler:Clean()
	Konsole.destroy()
end

return KonsoleHandler
