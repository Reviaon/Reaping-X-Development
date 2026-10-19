local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local EffectService = Jloader.GlobalFunctions.EffectService
local BlockLibrary = require("@game/ReplicatedStorage/Libraries/CharacterLibrary/BlockLibrary")

local Template = ReplicatedStorage:WaitForChild("Storage")
	:WaitForChild("Particles")
	:WaitForChild("CombatVFX")
	:WaitForChild("Hit")
	:WaitForChild("Daze")

local Settings = {
	Host = "Head",
	SpinSpeed = math.rad(120), --@ Radians per second around the head's up axis
	FadeTime = 0.4,
	Grace = 0.5, --@ Seconds past Info.Until before it fades even if GuardBroken never clears
}

local Daze = {}

local active = setmetatable({}, { __mode = "k" })

local function fade(character)
	local entry = active[character]
	if not entry then return end

	active[character] = nil
	entry.Watch:Disconnect()

	entry.Effect:FadeOutAll(Settings.FadeTime)
	entry.Effect:SetRemoval(Settings.FadeTime)

	task.delay(Settings.FadeTime, function()
		entry.Spin:Disconnect()
	end)
end

--@ Held on the victim's head for as long as GuardBroken lasts, then faded out. Info.Until is the
--@ lockout's end in server time: the relay can land before the attribute replicates.
function Daze.Attach(Info)
	local character = Info.Character
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return end
	if typeof(Info.Until) ~= "number" then return end

	local remaining = Info.Until - workspace:GetServerTimeNow()
	if remaining <= 0 then return end

	local host = character:FindFirstChild(Settings.Host)
	if not host then return end

	if active[character] then
		fade(character)
	end

	local effect = EffectService.new({ Effect = Template })
	effect:SetParent(host)

	local attachment = effect.Effect
	local base = Template.CFrame
	local angle = 0

	local entry = {
		Effect = effect,
		Spin = RunService.Heartbeat:Connect(function(deltaTime)
			if not attachment.Parent then return end

			angle = (angle + Settings.SpinSpeed * deltaTime) % (2 * math.pi)
			attachment.CFrame = base * CFrame.Angles(0, angle, 0)
		end),
		Watch = character:GetAttributeChangedSignal(BlockLibrary.BrokenStatus):Connect(function()
			if character:GetAttribute(BlockLibrary.BrokenStatus) ~= true then
				fade(character)
			end
		end),
	}

	active[character] = entry

	task.delay(remaining + Settings.Grace, function()
		if active[character] == entry then
			fade(character)
		end
	end)

	return effect
end

Daze.Settings = Settings

return Daze
