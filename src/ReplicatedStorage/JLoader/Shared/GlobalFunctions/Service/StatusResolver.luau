local StatusResolver = {}

function StatusResolver.Resolve(Attributes, Definitions, Defaults, Modes)
	local Active = {}
	for Name, Value in Attributes do
		if Value == true and Definitions[Name] then
			table.insert(Active, Name)
		end
	end
	table.sort(Active)

	local Resolved = table.clone(Defaults)
	for Property, Base in Defaults do
		local Override, Priority = Base, -math.huge
		local Add, Multiply = 0, 1
		local Minimum, Maximum = -math.huge, math.huge

		for _, Name in Active do
			local Definition = Definitions[Name]
			local Modifier = Definition.Modifiers and Definition.Modifiers[Property]
			local Value = Definition[Property]
			local Operation = Modes and Modes[Property] or "Override"
			if Modifier then
				Value = Modifier.Value
				Operation = Modifier.Operation
			end
			if Value == nil then
				continue
			end
			assert(typeof(Value) == typeof(Base), "Status property type mismatch: " .. Name .. "." .. Property)

			if Operation == "Override" then
				local Rank = Modifier and Modifier.Priority or Definition.Priority or 0
				if Rank > Priority then
					Override, Priority = Value, Rank
				elseif Rank == Priority then
					if typeof(Value) == "number" then
						Override = math.min(Override, Value)
					elseif typeof(Value) == "boolean" then
						Override = Override and Value
					end
				end
			else
				assert(typeof(Value) == "number" and Value == Value and math.abs(Value) < math.huge, "Expected a finite numeric modifier")
				if Operation == "Add" then
					Add += Value
				elseif Operation == "Multiply" then
					Multiply *= Value
				elseif Operation == "Min" then
					Maximum = math.min(Maximum, Value)
				elseif Operation == "Max" then
					Minimum = math.max(Minimum, Value)
				else
					error("Unknown status modifier operation: " .. tostring(Operation))
				end
			end
		end

		if typeof(Base) == "number" then
			Resolved[Property] = math.min(math.max((Override + Add) * Multiply, Minimum), Maximum)
		else
			Resolved[Property] = Override
		end
	end
	return Resolved
end

return StatusResolver
