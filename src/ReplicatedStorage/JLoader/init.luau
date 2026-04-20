--@ JLoader.lua V0.1 (Credits To Qbytez, Original Author Of Loader)
local RunService = game:GetService("RunService")

--@ Determine the environment and load the appropriate module
if RunService:IsServer() then
	--@ On the server, require and return the server module
	return require(script.Server)
else
	--@ On the client, destroy the server script for cleanup
	script.Server:Destroy()
	--@ Require and return the client module
	return require(script.Client)
end