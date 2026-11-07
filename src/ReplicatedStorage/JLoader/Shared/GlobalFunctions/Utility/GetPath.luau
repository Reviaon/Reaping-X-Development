--[[
	@Author: Jae
	@Date: 2024-09-27
	@Description: A utility module to read a path from a given string.
	
	@Version 1.0.0
]]--

local GetPath = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local cache = {}


local function split(path : string)
	local segments = {}
	for segment in string.gmatch(path, "[^/]+") do
		table.insert(segments, segment)
	end
	return segments
end

 
local function resolveRoot(name : string)
	local ok, service = pcall(game.GetService, game, name)
	if ok and service then
		return service
	end

	return ReplicatedStorage:FindFirstChild(name) or game:FindFirstChild(name)
end


function GetPath:ReadPath(Path : string?, timeout : number?)
	if type(Path) ~= "string" or Path == "" then
		warn("GetPath: asked to read an empty path")
		return nil
	end

	local cached = cache[Path]
	
	if cached then
		if cached:IsDescendantOf(game) then
			return cached
		end
		cache[Path] = nil
	end

	local segments = split(Path)
	if #segments == 0 then
		warn(("GetPath: '%s' has nothing in it to look up"):format(Path))
		return nil
	end

	local node = resolveRoot(segments[1])
	if not node then
		warn(("GetPath: '%s' starts at '%s', which is neither a service nor a folder in ReplicatedStorage"):format(Path, segments[1]))
		return nil
	end

	for index = 2, #segments do
		local name = segments[index]
		local child = node:FindFirstChild(name)

		if not child and timeout and timeout > 0 then
			child = node:WaitForChild(name, timeout)
		end

		if not child then
			warn(("GetPath: '%s' broke at '%s', because %s has no child by that name"):format(
				Path, name, node:GetFullName()))
			return nil
		end

		node = child
	end

	cache[Path] = node
	return node
end


function GetPath:_splitAttribute(Path : string?, timeout : number?)
	if type(Path) ~= "string" or Path == "" then
		warn("GetPath: asked to read an empty attribute path")
		return nil
	end

	local segments = split(Path)
	if #segments < 2 then
		warn(("GetPath: '%s' needs an instance and an attribute name, like 'Workspace/Weather'"):format(Path))
		return nil
	end

	local attribute = table.remove(segments)
	local instance = self:ReadPath(table.concat(segments, "/"), timeout)
	if not instance then
		return nil
	end

	return instance, attribute
end


function GetPath:ReadAttribute(Path : string?, timeout : number?)
	local instance, attribute = self:_splitAttribute(Path, timeout)
	if not instance then
		return nil
	end

	return instance:GetAttribute(attribute), instance, attribute
end


function GetPath:SetAttribute(Path : string?, value : any, timeout : number?)
	local instance, attribute = self:_splitAttribute(Path, timeout)
	if not instance then
		return false
	end

	instance:SetAttribute(attribute, value)
	return true
end


function GetPath:Clear()
	table.clear(cache)
end

return GetPath
