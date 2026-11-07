local RunService = game:GetService("RunService")

local Keys = require("@self/Keys")

local Blackboard = {}

Blackboard.Keys = Keys

local warned = {}

local function warnOnce(id: string, message: string)
	if warned[id] then return end

	warned[id] = true
	warn(message)
end

local Guard = {}

function Guard.__index(_, key)
	if not Keys[key] then
		warnOnce("read:" .. tostring(key), `[MobService] Blackboard read of undeclared key "{tostring(key)}" - declare it in MobService/Blackboard/Keys.`)
	end

	return nil
end

function Guard.__newindex(board, key, value)
	local spec = Keys[key]

	if not spec then
		warnOnce("write:" .. tostring(key), `[MobService] Blackboard write of undeclared key "{tostring(key)}" - declare it in MobService/Blackboard/Keys.`)
	elseif value ~= nil and typeof(value) ~= spec.Type then
		warnOnce("type:" .. key .. typeof(value), `[MobService] Blackboard.{key} expects {spec.Type}, got {typeof(value)}.`)
	end

	rawset(board, key, value)
end

function Blackboard.new(): { [string]: any }
	return if RunService:IsStudio() then setmetatable({}, Guard) else {}
end

return Blackboard
