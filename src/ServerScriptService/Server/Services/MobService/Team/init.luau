local Config = require("@self/Config")

local PARTS = {
	require("@self/Targets"),
	require("@self/Balance"),
	require("@self/Slots"),
	require("@self/BreakIns"),
	require("@self/Reservations"),
	require("@self/Orbit"),
	require("@self/Reach"),
	require("@self/Sightings"),
}

local Team = {}
Team.__index = Team
Team.Settings = Config

for _, part in PARTS do
	for name, method in part.Methods do
		assert(Team[name] == nil, `[Team] two parts define {name}`)
		Team[name] = method
	end
end

local teams = {}

local function create(key: any)
	local team = { Key = key, Members = {} }

	for _, part in PARTS do
		for field, value in part.State() do
			team[field] = value
		end
	end

	return setmetatable(team, Team)
end

function Team.Join(mob, key: any)
	if key == nil then return nil end

	local team = teams[key]

	if not team then
		team = create(key)
		teams[key] = team
	end

	team.Members[mob] = true
	mob.Team = team

	return team
end

function Team.Get(key: any)
	return teams[key]
end

function Team:Describe(mob): { string }
	local members = 0

	for _ in self.Members do
		members += 1
	end

	local lines = { `pack of {members}` }

	for _, part in PARTS do
		if part.Describe then
			for _, line in part.Describe(self, mob) do
				table.insert(lines, line)
			end
		end
	end

	return lines
end

function Team:Leave(mob)
	self.Members[mob] = nil

	for _, part in PARTS do
		if part.Forget then
			part.Forget(self, mob)
		end
	end

	if next(self.Members) == nil then
		teams[self.Key] = nil
	end
end

return Team
