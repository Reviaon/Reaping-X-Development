local PositionService = {}

PositionService.Settings = {
	--@ Seconds between a client's root reports.
	ReportInterval = 0.1,

	--@ Studs a report may sit from the server's own view of that root before it is rejected.
	MaxDrift = 25,

	--@ Seconds a report stays usable before the live root is used instead.
	Staleness = 0.5,

	--@ Studs of movement below which a report is skipped.
	MinDelta = 0.5,
}

local reports = setmetatable({}, { __mode = "k" })

local function rootOf(character): BasePart?
	if typeof(character) ~= "Instance" then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

function PositionService.Pack(cframe: CFrame): { number }
	local position, look = cframe.Position, cframe.LookVector
	return { position.X, position.Y, position.Z, look.X, look.Y, look.Z }
end

function PositionService.Unpack(payload): (Vector3?, Vector3?)
	if typeof(payload) ~= "table" then return nil, nil end

	local numbers = table.create(6)

	for index = 1, 6 do
		local value = tonumber(payload[index])

		if not value or value ~= value or math.abs(value) == math.huge then
			return nil, nil
		end

		numbers[index] = value
	end

	local look = Vector3.new(numbers[4], numbers[5], numbers[6])

	return Vector3.new(numbers[1], numbers[2], numbers[3]),
		look.Magnitude > 1e-3 and look.Unit or nil
end

function PositionService.Accept(character, payload): boolean
	local root = rootOf(character)
	if not root then return false end

	local position, look = PositionService.Unpack(payload)
	if not position then return false end

	if (position - root.Position).Magnitude > PositionService.Settings.MaxDrift then
		return false
	end

	reports[character] = {
		position = position,
		look = look or root.CFrame.LookVector,
		at = os.clock(),
	}

	return true
end

function PositionService.Clear(character)
	if typeof(character) ~= "Instance" then return end
	reports[character] = nil
end

function PositionService.Reference(character): (Vector3?, Vector3?)
	local root = rootOf(character)
	if not root then return nil, nil end

	local entry = reports[character]

	if entry and os.clock() - entry.at <= PositionService.Settings.Staleness then
		return entry.position, entry.look
	end

	return root.Position, root.CFrame.LookVector
end

--@ Where a hit sends its victim, and the line from attacker to victim (for turning the victim to
--@ face them). The throw follows the attacker's look, so it goes where the swing was aimed however
--@ far off its centre the victim stood; a victim behind the attacker is thrown along the line instead
function PositionService.Aim(attacker, victim): (Vector3, Vector3)
	local attackerPosition, attackerLook = PositionService.Reference(attacker)
	local victimPosition = PositionService.Reference(victim)

	if not attackerPosition or not victimPosition then
		return Vector3.zero, Vector3.zero
	end

	local planar = Vector3.new(1, 0, 1)
	local look = (attackerLook or Vector3.zero) * planar
	local offset = (victimPosition - attackerPosition) * planar

	local away = offset.Magnitude > 1e-3 and offset.Unit or nil
	local aimed = look.Magnitude > 1e-3 and look.Unit or nil

	if aimed and away and aimed:Dot(away) < 0 then
		aimed = nil
	end

	local direction = aimed or away or Vector3.zero

	return direction, away or direction
end

return PositionService
