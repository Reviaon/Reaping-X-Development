--@ Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jloader = require(ReplicatedStorage:WaitForChild("JLoader"))
local GlobalFunctions = Jloader.GlobalFunctions

local DataService = Jloader.CreateService({ Name = script.Name })

--@ Dependencies
local Libraries = ReplicatedStorage:WaitForChild("Libraries")

local ProfileService = require(script.Parent.Parent:WaitForChild("ProfileService"))
local TempData = require(Libraries:WaitForChild("TempData"))

--@ Shared
local ProfileStores = {
	Player = ProfileService.GetProfileStore("PlayerData", TempData.plrData);
}

--Creates a mock version of the data if the player is in studio

--if RunService:IsStudio() then
--	ProfileStores.Player = ProfileStores.Player.Mock
--end

local dataVersion = "0.0.1"
local dataType = "Reaping"
local dataKey = dataType..dataVersion.."_"

local Handlers = {}
local Data = {}

local handlersFolder = script:FindFirstChild("Handlers")
for _,v in handlersFolder and handlersFolder:GetChildren() or {} do
	if v:IsA("ModuleScript") then
		local success, err = pcall(function()
			return require(v)
		end)
		if success then
			if Handlers[v.Name] == nil then
				Handlers[v.Name] = err
			end
		end
	end
end


function DataService.GetDataKey()
	return dataKey    
end

function DataService.InitGlobal(scope)

end

function DataService.InitPlr(plr, scope)
	if ProfileStores[scope] == nil then return end
	local profile = ProfileStores[scope]:LoadProfileAsync(dataKey..plr.UserId)
	if profile ~= nil then
		profile:AddUserId(plr.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			if Data[plr][scope] then
				Data[plr][scope] = nil
			end

			plr:Kick()
		end)
		if plr:IsDescendantOf(Players) == true then
			if Data[plr] == nil then
				Data[plr] = {}
			end
			Data[plr][scope] = profile
			if Handlers[scope] ~= nil then
				Handlers[scope](plr, profile)

				warn(Data[plr][scope])
				warn(profile)
			end
			
			local publicDataFolder = Instance.new("Folder")
			publicDataFolder.Name = "Data"
			publicDataFolder.Parent = plr
			
			local valueTbl = {
				["number"] = "NumberValue",
				["string"] = "StringValue",
				["boolean"] = "BoolValue",
				["table"] = "Folder",
			}
			
			local function recursiveToValue(instance)
				local newVal = {}
				newVal.index = instance.Name
				local currentVal
				local function getValue(index,instance)
					local valForInstance
					
					if instance.ClassName == "Folder" then
						valForInstance = {} 
					else
						valForInstance = instance.Value
					end
					
					local foundTbl = currentVal
					
					if currentVal then
						for i,v in pairs(index) do
							foundTbl = foundTbl[v]
						end
						
						foundTbl[instance.Name] = valForInstance
						
						table.insert(index,instance.Name)
						
					else
						currentVal = valForInstance
					end
					
					local children = instance:GetChildren()
					if #children > 0 and instance.ClassName == "Folder" then
						for i,v in pairs(children) do
							getValue(index,v) 
						end
					end
					
				end
				getValue({},instance)
				newVal.value = currentVal
				return newVal
			end
			
			local making = true
			local function recursiveCreate(parent,tbl)
				local function makeValue(tbl,index,val)
					local className = typeof(val)
					
					local newVal = Instance.new(valueTbl[className])
					newVal.Name = index
					newVal.Parent = parent
					
					if newVal.ClassName ~= "Folder" then
						
						newVal.Value = val
						
						newVal.Changed:Connect(function(newVal)
							if not plr or (plr and not plr:IsDescendantOf(Players)) then return end
							tbl[index] = newVal
						
							if plr and plr.Character then
								
							end
						end)

					else

						newVal.ChildAdded:Connect(function(child)
							if making == true then return end
							if not plr or (plr and not plr:IsDescendantOf(Players)) then return end
							local valToAdd = recursiveToValue(child)
							tbl[index][valToAdd.index] = valToAdd.value
							
							local function setupCon(child,tbl,index)
								if child.ClassName ~= "Folder" then
									
									child.Changed:Connect(function(newVal)
										tbl[index] = newVal
									end)
								else
									for i,v in pairs(child:GetChildren()) do
										setupCon(v,tbl[index],v.Name) 
									end
								end
							end
							setupCon(child,tbl[index],valToAdd.index)
							
						end)
						
						newVal.ChildRemoved:Connect(function(child)
							warn("removedd?? :(")
							if not plr or (plr and not plr:IsDescendantOf(Players)) then return end
							local newIndex = child.Name 
							tbl[index][newIndex] = nil 
						end)
						
					end
					
					if className == "table" then
						recursiveCreate(newVal,val) 
					end
					
				end
				
				for i,v in pairs(tbl) do
					makeValue(tbl,i,v)
				end
				
			end
			
			recursiveCreate(publicDataFolder,profile.Data)
			
		else
			profile:Release()
		end
	else
		plr:Kick()
	end
end

function DataService.GetPlrData(plr, scope)
	if Data[plr] == nil then return nil end
	local profile = Data[plr][scope]
	if profile == nil then return nil end

	return profile.Data
end
function DataService.RemovePlr(plr, scope)
	if Data[plr] == nil then return end
	local profile = Data[plr][scope]
	--print("RELEASING",profile)
	if profile ~= nil then
		profile:Release()
	end
end

return DataService