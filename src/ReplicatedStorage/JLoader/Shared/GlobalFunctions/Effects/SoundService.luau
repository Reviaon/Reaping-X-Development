local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundsCache = ReplicatedStorage.Storage.Sounds

local SoundUtils = {}

local function CloneSound(Sound: Sound, Properties: {[string]: any})
	local NewSound = Sound:Clone()
	NewSound.SoundGroup = SoundService.Main

	if Properties then
		for Property, Value in Properties do
			NewSound[Property] = Value
		end
	end
	return NewSound
end

local function CreateSound(Properties: {[string]: any})
	local Sound = Instance.new("Sound")
	Sound.SoundGroup = SoundService.Main

	if Properties then
		for Property, Value in Properties do
			Sound[Property] = Value
		end
	end
	return Sound
end

function SoundUtils:PlayLocalSound(Sound: string | Sound) : Sound?
	local Sound = (typeof(Sound) == "string" 
		and SoundsCache:FindFirstChild(Sound, true) or Sound
	)

	assert(Sound, `Sound: {Sound} does not exist.`)

	SoundService:PlayLocalSound(Sound)
	return Sound
end

function SoundUtils:CloneSound(Sound: Sound | string, Play: boolean, Properties: {[string]: any}) : Sound
	local Sound = (typeof(Sound) == "Instance" and Sound
		or SoundsCache:FindFirstChild(Sound, true)
	)
	
	assert(Sound, `Invalid sound: {Sound}`)

	local NewSound = CloneSound(Sound, Properties)
	NewSound.Played:Connect(function()
		NewSound.Ended:Connect(function()
			NewSound:Destroy()
		end)
	end)

	if NewSound and Play then
		NewSound:Play()
	end
	return NewSound
end

function SoundUtils:CreateSound(Play: boolean, Properties: {[string]: any}) : Sound
	local Sound = CreateSound(Properties)
	Sound.Played:Connect(function()
		Sound.Ended:Connect(function()
			Sound:Destroy()
		end)
	end)

	if Play then
		Sound:Play()
	end
	return Sound
end

function SoundUtils:Play3DSound(
	Sound: Sound | string | number, 
	Position: Vector3,
	Properties: {[string]: any}
) : Sound

	local SoundId = (typeof(Sound) == "Instance" and Sound.SoundId 
		or typeof(Sound) == "string" and Sound 
		or typeof(Sound) == "number" and `rbxassetid://{Sound}`
	)

	local Attachment = Instance.new("Attachment")
	Attachment.WorldPosition = Position
	Attachment.Parent = workspace.Terrain

	local NewSound
	if typeof(Sound) ~= "Instance" then
		NewSound = CreateSound(Properties)
		NewSound.SoundId = SoundId
	else
		NewSound = CloneSound(Sound, Properties)
		NewSound.SoundId = SoundId
	end

	NewSound.Parent = Attachment
	NewSound:Play()

	NewSound.Ended:Connect(function()
		Attachment:Destroy()
	end)
	return NewSound
end

return SoundUtils
