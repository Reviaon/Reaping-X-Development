--@ Start
local Jloader = require(game.ReplicatedStorage.JLoader)
local GlobalFunctions = Jloader.GlobalFunctions

--@ Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--@ Constants
local HIGHLIGHT_FADE = TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

return function(Data) : ()
	local Entity = Data.Char
	local LifeTime = Data.LifeTime
	
	local StartTime = os.clock()
	local ForceField: RBXScriptConnection = nil
		
	local Highlight = Instance.new("Highlight")
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.FillColor = Color3.fromRGB(0, 200, 255)
	Highlight.FillTransparency = 0.7
	Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	Highlight.OutlineTransparency = 0.5
	Highlight.Parent = Entity
		
	local function Remove()
		local ClientTween = TweenService:Create(Highlight, HIGHLIGHT_FADE, {
			FillTransparency = 1, OutlineTransparency = 1
		})
		ClientTween:Play()
		
		ClientTween.Completed:Connect(function()
			ClientTween:Destroy()
			ClientTween = nil
			
			Highlight:Destroy()
		end)
	end
	
	ForceField = RunService.Heartbeat:Connect(function(dt: number)
		if not Entity.Parent then
			return ForceField:Disconnect()
		end
		
		if LifeTime and os.clock() - StartTime >= LifeTime
			or Entity.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead
			and Entity.Humanoid.MoveDirection ~= Vector3.zero
		then
			ForceField:Disconnect()
			Remove()
		end
	end)
	
	return Remove
end