local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local ChronoHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")

local Chrono = require("@game/ReplicatedStorage/Libraries/Chrono")

local pausedEntities = setmetatable({}, { __mode = "k" })

local function clearOnPauseChange()
	for _, entity in Chrono.Holder.idMap do
		local paused = entity.paused == true

		if paused == (pausedEntities[entity] == true) then continue end

		pausedEntities[entity] = paused or nil

		if not entity.isContextOwner then
			Chrono.Entity.Clear(entity)
		end
	end
end

function ChronoHandler:Load()
	Chrono.Start(ReplicatedStorage.Libraries.ReplicationLibrary.ChronoConfig)

	RunService.PreSimulation:Connect(clearOnPauseChange)
end

return ChronoHandler
