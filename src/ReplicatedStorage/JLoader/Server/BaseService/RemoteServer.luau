--@ RemoteServer — server-side signal, now backed by ByteNet via Net.
--  Public API is unchanged (:Fire/:FireAll/:FireExcept/:FireFilter/:Connect),
--  only the transport differs. Each instance owns a stable `Channel` string.

local Players = game:GetService("Players")

local Shared = script.Parent.Parent.Parent.Shared
local Net = require(Shared.GlobalFunctions).Net

local ServerSignal = {}
ServerSignal.__index = ServerSignal

--@ Create a new server signal for the given channel
ServerSignal.new = function(channel: string)
	local self = setmetatable({
		Name = channel,
		Channel = channel,
		Connections = {},
	}, ServerSignal)
	return self
end

--@ Fire the signal to a specific player
function ServerSignal:Fire(plr: Player, ...)
	Net.fireTo(self.Channel, plr, ...)
end

--@ Fire the signal to all players
function ServerSignal:FireAll(...)
	Net.fireAll(self.Channel, ...)
end

--@ Fire the signal to all players except the specified player
function ServerSignal:FireExcept(plr: Player, ...)
	Net.fireExcept(self.Channel, plr, ...)
end

--@ Fire the signal to players that meet the filter criteria
function ServerSignal:FireFilter(filter, ...)
	filter = filter or function() return true end
	for _, p in ipairs(Players:GetPlayers()) do
		if filter(p) then
			Net.fireTo(self.Channel, p, ...)
		end
	end
end

--@ Connect a function to the signal. Handler receives (player, ...).
function ServerSignal:Connect(f)
	local con = Net.onEvent(self.Channel, f)
	table.insert(self.Connections, con)
	return con
end

--@ Disconnect every connection made through this signal
function ServerSignal:Disconnect()
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
	self.Connections = {}
end

ServerSignal.Destroy = ServerSignal.Disconnect

return ServerSignal
