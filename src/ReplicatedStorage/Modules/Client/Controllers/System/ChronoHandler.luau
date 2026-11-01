local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local ChronoHandler = Jloader.CreateHandler({ Name = script.Name })

local RunService = game:GetService("RunService")

local Chrono = require("@game/ReplicatedStorage/Libraries/Chrono")
local ChronoConfig = require("@game/ReplicatedStorage/Libraries/ReplicationLibrary/ChronoConfig")

local pausedEntities = setmetatable({}, { __mode = "k" })

local function holdsPause(model: Instance?): boolean
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return false end

	for _, status in ChronoConfig.PauseStatuses do
		if model:GetAttribute(status) == true then return true end
	end

	return false
end

local function clearOnPauseChange()
	for _, entity in Chrono.Holder.idMap do
		if not entity.paused and holdsPause(entity.model) then
			Chrono.Entity.PauseReplication(entity)
		end

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
