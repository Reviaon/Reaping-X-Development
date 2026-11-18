--[[@
	**Saved**: the player's set choice, kept in their saved data
	- **Where:** `Config.Save`: the data scope, the table path inside it, and the key
	- **Read:** the saved set name; `""` means they chose none; a player who never chose wears `Config.Default`
	- **Write:** through the scope's replicated Values when it mirrors, so the client sees it and the profile follows; straight into the profile otherwise
	- **Wait:** yields until the player's data has loaded, up to `Config.Save.Timeout` seconds
	- **No data:** reads give `Config.Default`, writes are dropped
]]
local DataConfig = require("../DataService/Config")
local DataService = require("../DataService")

local Config = require("./Config")

local Saved = {}

local function tableOf(player: Player): { [string]: any }?
	local data: any = DataService:Get(player, Config.Save.Scope)

	for _, key in Config.Save.Path do
		data = if typeof(data) == "table" then data[key] else nil
	end

	return if typeof(data) == "table" then data else nil
end

local function folderOf(player: Player): Instance?
	local store = DataConfig.Stores[Config.Save.Scope]
	local folder = store and store.Replicate and player:FindFirstChild(store.Replicate)

	for _, key in Config.Save.Path do
		folder = folder and folder:FindFirstChild(key)
	end

	return folder
end

function Saved.Wait(player: Player): boolean
	local deadline = os.clock() + Config.Save.Timeout

	while not DataService:Get(player, Config.Save.Scope) do
		if not player.Parent or os.clock() > deadline then return false end

		task.wait(0.1)
	end

	return true
end

function Saved.Get(player: Player): string?
	local saved = tableOf(player)
	local name = saved and saved[Config.Save.Key]

	if typeof(name) ~= "string" then return Config.Default end

	return if name == "" then nil else name
end

function Saved.Set(player: Player, name: string?)
	local value = name or ""
	local folder = folderOf(player)

	if folder then
		local existing = folder:FindFirstChild(Config.Save.Key)

		if existing and existing:IsA("StringValue") then
			existing.Value = value
			return
		end

		if existing then
			existing:Destroy()
		end

		local created = Instance.new("StringValue")
		created.Name = Config.Save.Key
		created.Value = value
		created.Parent = folder

		return
	end

	local saved = tableOf(player)

	if saved then
		saved[Config.Save.Key] = value
	end
end

return Saved
