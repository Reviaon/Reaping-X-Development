local Jloader = require("@game/ReplicatedStorage/JLoader")
local Chrono = require("@game/ReplicatedStorage/Libraries/Chrono")
local ChronoConfig = require("@game/ReplicatedStorage/Libraries/ReplicationLibrary/ChronoConfig")

local ChronoService = Jloader.CreateService({ Name = script.Name })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Entity = Chrono.Entity

local npcEntities = {}

local function liveFolder(): Instance
	local folder: Instance = workspace

	for segment in string.gmatch(ChronoConfig.LiveFolder, "[^/]+") do
		folder = folder:WaitForChild(segment)
	end

	return folder
end

local function watchPause(character: Model, entity)
	local function sync()
		if entity.destroyed then return end

		if character:GetAttribute(ChronoConfig.PauseStatus) == true then
			Entity.PauseReplication(entity)
		else
			Entity.ResumeReplication(entity)
		end
	end

	local connection = character:GetAttributeChangedSignal(ChronoConfig.PauseStatus):Connect(sync)

	Entity.GetEvent(entity, "Destroying"):Once(function()
		connection:Disconnect()
	end)

	sync()
end

local function adoptNpc(model: Instance)
	if not model:IsA("Model") or npcEntities[model] then return end
	if Players:GetPlayerFromCharacter(model) then return end
	if not model:FindFirstChildOfClass("Humanoid") or not model:FindFirstChild(ChronoConfig.PrimaryPart) then return end

	Chrono.Config.SetModelPrimaryForChrono(model, ChronoConfig.PrimaryPart)

	local entity = Entity.new(ChronoConfig.NpcType, model)
	npcEntities[model] = entity

	watchPause(model, entity)

	local connection
	connection = model.AncestryChanged:Connect(function()
		if model:IsDescendantOf(game) then return end

		connection:Disconnect()
		npcEntities[model] = nil

		if not entity.destroyed then
			Entity.Destroy(entity)
		end
	end)
end

function ChronoService:GetEntity(character: Model)
	return Chrono.Holder.GetEntityFromModel(character)
end

function ChronoService:Init()
	Chrono.Start(ReplicatedStorage.Libraries.ReplicationLibrary.ChronoConfig)

	Chrono.Events.PlayerCharacterRegistered:Connect(function(_, entity)
		local character = entity.model

		if character and character:IsA("Model") then
			watchPause(character, entity)
		end
	end)

	task.spawn(function()
		local live = liveFolder()

		for _, child in live:GetChildren() do
			task.defer(adoptNpc, child)
		end

		live.ChildAdded:Connect(function(child)
			task.defer(adoptNpc, child)
		end)
	end)
end

return ChronoService
