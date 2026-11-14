--[[@
	**DataService**: loads, replicates and releases each player's saved data
	- **Open** loads the scope's profile (session-locked) and reconciles it against the store's template
	  - It runs the optional `Handlers/<Scope>` module, then mirrors the data to the Player if the store replicates
	  - It yields, so `GameService` builds the character only once data is in
	- **Kicks:** if the profile can't load, or another server takes its lock
	- **Close** saves and unlocks; `GameService` calls it on leave and at shutdown
	- **Get** returns the live data table; edit replicated data through its Values (see `Mirror`)
	- **Names:** never `Load`, `InitPlayer` or `InitCharacter`, which JLoader calls on every service
]]
local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")

local Config = require("@self/Config")
local Mirror = require("@self/Mirror")
local Stores = require("@self/Stores")
local Types = require("@self/Types")

type Data = Types.Data
type Handler = Types.Handler
type Session = Types.Session

local DataService = Jloader.CreateService({ Name = script.Name })

local Sessions: { [Player]: { [string]: Session } } = {}

local function handlerOf(scope: string): Handler?
	local handlers = script:FindFirstChild("Handlers")
	local module = handlers and handlers:FindFirstChild(scope)

	if not module or not module:IsA("ModuleScript") then return nil end

	local loaded, handler = pcall(require, module)

	if not loaded or typeof(handler) ~= "function" then
		warn(`[DataService] Handlers.{scope} didn't load a function: {handler}`)
		return nil
	end

	return handler :: Handler
end

local function forget(player: Player, scope: string)
	local sessions = Sessions[player]
	if not sessions then return end

	sessions[scope] = nil

	if next(sessions) == nil then
		Sessions[player] = nil
	end
end

function DataService:Open(player: Player, scope: string): Data?
	local store = Config.Stores[scope]
	local profileStore = Stores.Get(scope)

	if not store or not profileStore then
		warn(`[DataService] No store for scope "{scope}"`)
		return nil
	end

	local profile = profileStore:LoadProfileAsync(Config.Prefix .. player.UserId)

	if not profile then
		player:Kick(Config.Kick.Failed)
		return nil
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	local session: Session = { Profile = profile, Folder = nil }

	profile:ListenToRelease(function()
		local sessions = Sessions[player]
		if not sessions or sessions[scope] ~= session then return end

		forget(player, scope)

		if player.Parent then
			player:Kick(Config.Kick.Released)
		end
	end)

	if not player:IsDescendantOf(Players) then
		profile:Release()
		return nil
	end

	Sessions[player] = Sessions[player] or {}
	Sessions[player][scope] = session

	local handler = handlerOf(scope)

	if handler then
		handler(player, profile)
	end

	if store.Replicate then
		session.Folder = Mirror.Build(store.Replicate, profile.Data, player)
	end

	return profile.Data
end

function DataService:Get(player: Player, scope: string): Data?
	local sessions = Sessions[player]
	local session = sessions and sessions[scope]

	return if session then session.Profile.Data else nil
end

function DataService:Close(player: Player, scope: string)
	local sessions = Sessions[player]
	local session = sessions and sessions[scope]
	if not session then return end

	forget(player, scope)

	if session.Profile:IsActive() then
		session.Profile:Release()
	end
end

return DataService
