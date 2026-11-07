local DebugService = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

DebugService.Settings = {
	--@ Replicated flag. Unset falls back to Studio, so nothing changes until it is set.
	Attribute = "DebugMode",

	--@ String attribute a server system sets on a model to show one debug line over it.
	Overhead = "DebugOverhead",
}

function DebugService.IsEnabled(): boolean
	local value = ReplicatedStorage:GetAttribute(DebugService.Settings.Attribute)

	if typeof(value) == "boolean" then
		return value
	end

	return RunService:IsStudio()
end

function DebugService.Set(enabled: boolean): boolean
	local value = enabled and true or false
	ReplicatedStorage:SetAttribute(DebugService.Settings.Attribute, value)
	return value
end

function DebugService.Toggle(): boolean
	return DebugService.Set(not DebugService.IsEnabled())
end

function DebugService.Changed(callback)
	return ReplicatedStorage
		:GetAttributeChangedSignal(DebugService.Settings.Attribute)
		:Connect(function()
			callback(DebugService.IsEnabled())
		end)
end

return DebugService
