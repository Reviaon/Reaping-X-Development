--[[@
	**Stores**: one ProfileService store per configured scope, opened on first use
	- **Mock:** with `MockInStudio` on, Studio loads from the store's mock, so tests never touch real saves
]]
local RunService = game:GetService("RunService")

local ProfileService = require("@game/ServerScriptService/Server/ProfileService")

local Config = require("./Config")
local Types = require("./Types")

type ProfileStore = Types.ProfileStore

local Stores = {}

local Opened: { [string]: ProfileStore } = {}

function Stores.Get(scope: string): ProfileStore?
	local opened = Opened[scope]
	if opened then return opened end

	local store = Config.Stores[scope]
	if not store then return nil end

	local profileStore = ProfileService.GetProfileStore(store.Name, store.Template) :: ProfileStore

	if Config.MockInStudio and RunService:IsStudio() then
		profileStore = profileStore.Mock
	end

	Opened[scope] = profileStore

	return profileStore
end

return Stores
