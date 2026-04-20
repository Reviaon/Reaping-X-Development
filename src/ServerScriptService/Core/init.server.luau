--@ Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--@ Import
local JLoader = require(ReplicatedStorage:WaitForChild("JLoader"))
JLoader.LoadServices({ServerScriptService.Server.Services})
JLoader.Load()