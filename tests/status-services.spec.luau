return function(sources)
	local passed = {}
	local function equal(actual, expected)
		assert(actual == expected, string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
	end

	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				local token = {}
				listeners[token] = fn
				return { Disconnect = function() listeners[token] = nil end }
			end,
			Fire = function(_, ...)
				local snapshot = table.clone(listeners)
				for token, fn in snapshot do
					if listeners[token] then fn(...) end
				end
			end,
		}
	end

	local function environment()
		local time, jobs = 100, {}
		local clock = {}
		function clock.advance(delta)
			local target = time + delta
			while true do
				local nextJob
				for _, job in jobs do
					if not job.done and not job.cancelled and job.at <= target
						and (not nextJob or job.at < nextJob.at) then
						nextJob = job
					end
				end
				if not nextJob then break end
				time = nextJob.at
				nextJob.done = true
				nextJob.fn()
			end
			time = target
		end
		function clock.skip(delta) time += delta end

		local fakeTask = {
			delay = function(duration, fn)
				local job = { at = time + duration, fn = fn }
				table.insert(jobs, job)
				return job
			end,
			cancel = function(job) job.cancelled = true end,
		}
		local modules = {}
		local parent = { StatusService = "status", StatusResolver = "resolver" }
		local replicated = { Libraries = { CharacterLibrary = { StatusLibrary = "library" } }, JLoader = "loader" }
		local fakeGame = { ReplicatedStorage = replicated, GetService = function() return replicated end }
		local fakeWorkspace = { GetServerTimeNow = function() return time end }
		local function fakeType(value)
			if type(value) == "table" and value._instance then return "Instance" end
			return typeof(value)
		end
		local function load(name, source)
			local fn, err = loadstring("local game, workspace, task, require, script, typeof = ...\n" .. source)
			assert(fn, err)
			modules[name] = fn(fakeGame, fakeWorkspace, fakeTask, function(key)
				assert(modules[key], "Unexpected dependency: " .. tostring(key))
				return modules[key]
			end, { Parent = parent }, fakeType)
			return modules[name]
		end
		load("library", sources.library)
		load("resolver", sources.resolver)
		local status = load("status", sources.status)
		local cooldown = load("cooldown", sources.cooldown)
		modules.loader = { CreateHandler = function(template) return template end }
		local properties = load("properties", sources.properties)

		local function model()
			local attributes = {}
			local humanoid = { _instance = true, Health = 100, AutoRotate = false, Jump = true, Died = signal(), Jumping = signal() }
			function humanoid:IsA(class) return class == "Humanoid" end
			local label = { Text = "" }
			local gui = { FindFirstChildWhichIsA = function() return label end }
			local entity = {
				_instance = true, Name = "Test", Parent = {},
				Destroying = signal(), AncestryChanged = signal(), ChildAdded = signal(), AttributeChanged = signal(),
			}
			function entity:IsA(class) return class == "Model" end
			function entity:GetAttribute(key) return attributes[key] end
			function entity:GetAttributes() return table.clone(attributes) end
			function entity:SetAttribute(key, value)
				local old = attributes[key]
				attributes[key] = value
				if old ~= value then self.AttributeChanged:Fire(key) end
			end
			function entity:FindFirstChildOfClass(class)
				if class == "Humanoid" then return humanoid end
				return nil
			end
			function entity:FindFirstChild(name)
				if name == "DebugStatusUI" then return gui end
				return nil
			end
			function entity:IsDescendantOf() return self.Parent ~= nil end
			function entity:Destroy()
				self.Destroying:Fire()
				self.Parent = nil
				self.AncestryChanged:Fire(self, nil)
			end
			return entity, humanoid, label
		end

		local function trove()
			local resources = {}
			local object = {}
			function object:Add(item) table.insert(resources, item); return item end
			function object:Connect(event, fn) return self:Add(event:Connect(fn)) end
			function object:Clean()
				local previous = resources
				resources = {}
				for _, item in previous do
					if type(item) == "function" then item() else item:Disconnect() end
				end
			end
			object.Destroy = object.Clean
			return object
		end
		local function controller(entity, humanoid)
			local scopes = {}
			local c = {
				Character = entity, Humanoid = humanoid, StatusService = status,
				Trove = { new = trove },
				DebugService = { IsEnabled = function() return false end, Changed = function() return { Disconnect = function() end } end },
			}
			function c:Scope(key)
				scopes[key] = scopes[key] or {}
				return scopes[key]
			end
			function c:Set(key, value) self[key] = value end
			function c:Get(key) return self[key] end
			return c
		end
		return { status = status, cooldown = cooldown, properties = properties, clock = clock,
			model = model, controller = controller, jobs = jobs, resolver = modules.resolver, library = modules.library }
	end

	local function test(name, fn)
		local e = environment()
		local ok, err = pcall(fn, e)
		assert(ok, name .. ": " .. tostring(err))
		table.insert(passed, name)
	end

	test("legacy refresh preserves a longer expiry", function(e)
		local m = e.model()
		e.status:SetStatus(m, "IsStunned", true, 5)
		e.clock.advance(1)
		e.status:SetStatus(m, "IsStunned", true, 0.1)
		e.clock.advance(0.2)
		equal(m:GetAttribute("IsStunned"), true)
		e.clock.advance(3.8)
		equal(m:GetAttribute("IsStunned"), nil)
	end)

	test("independent sources expire independently", function(e)
		local m = e.model()
		local long = e.status:ApplyStatus(m, "IsStunned", true, 5)
		local short = e.status:ApplyStatus(m, "IsStunned", true, 0.1)
		e.clock.advance(0.1)
		equal(short:GetRemainingTime(), 0)
		equal(m:GetAttribute("IsStunned"), true)
		long:Destroy()
		equal(m:GetAttribute("IsStunned"), nil)
		long:Destroy()
	end)

	test("named source replacement invalidates the previous handle", function(e)
		local m = e.model()
		local old = e.status:SetStatus(m, "Buff", true, 2, "potion")
		local fresh = e.status:SetStatus(m, "Buff", true, 4, "potion")
		old:Destroy()
		equal(m:GetAttribute("Buff"), true)
		equal(fresh:GetRemainingTime(), 4)
	end)

	test("source removal preserves other owners", function(e)
		local m = e.model()
		e.status:SetStatus(m, "Buff", true, nil, "equipment")
		e.status:SetStatus(m, "Buff", true, 2, "potion")
		e.status:SetStatus(m, "Other", true, 2, "potion")
		e.status:RemoveSource(m, "potion")
		equal(m:GetAttribute("Buff"), true)
		equal(m:GetAttribute("Other"), nil)
		e.status:RemoveStatus(m, "Buff", "equipment")
		equal(m:GetAttribute("Buff"), nil)
	end)

	test("expired latest value restores an earlier source", function(e)
		local m = e.model()
		e.status:SetStatus(m, "Direction", "A", nil, "first")
		e.status:SetStatus(m, "Direction", "B", 0.5, "second")
		equal(m:GetAttribute("Direction"), "B")
		e.clock.advance(0.5)
		equal(m:GetAttribute("Direction"), "A")
	end)

	test("stale expiry cannot clear replacement", function(e)
		local m = e.model()
		e.status:SetStatus(m, "Flag", true, 1)
		local stale = e.jobs[1]
		e.status:SetStatus(m, "Flag", "replacement", 2)
		stale.fn()
		equal(m:GetAttribute("Flag"), "replacement")
	end)

	test("zero duration removes only the requested source", function(e)
		local m = e.model()
		e.status:SetStatus(m, "Flag", true)
		e.status:SetStatus(m, "Flag", true, nil, "other")
		e.status:SetStatus(m, "Flag", true, 0)
		equal(m:GetAttribute("Flag"), true)
		e.status:SetStatus(m, "Flag", true, 0, "other")
		equal(m:GetAttribute("Flag"), nil)
		equal(e.status:ApplyStatus(m, "Zero", true, 0), nil)
		equal(m:GetAttribute("Zero"), nil)
	end)

	test("false checks and default exclusions are exact", function(e)
		local m = e.model()
		e.status:SetStatus(m, "IsStunned", false)
		equal(e.status:CheckStatuses(m, { IsStunned = false }), true)
		equal(e.status:CheckStatuses(m, { Default = true }), false)
		e.status:SetStatus(m, "IsStunned", true)
		equal(e.status:CheckStatuses(m, { Default = true, IsStunned = false }), false)
		e.status:SetStatus(m, "IsDiving", true)
		equal(e.status:CheckStatuses(m, { Default = true, IsStunned = false }), true)
	end)

	test("batch status calls accept arrays and dictionaries", function(e)
		local m = e.model()
		e.status:SetStatuses(m, { {Status = "A", Value = true}, {Status = "B", Value = true} })
		equal(e.status:CheckStatuses(m, {"A", "B"}), true)
		e.status:RemoveStatuses(m, {"A"})
		e.status:RemoveStatuses(m, { B = true })
		equal(m:GetAttribute("A"), nil)
		equal(m:GetAttribute("B"), nil)
		m:SetAttribute("Untracked", true)
		e.status:RemoveStatus(m, "Untracked")
		equal(m:GetAttribute("Untracked"), nil)
	end)

	test("profile cleanup cancels timers and invalidates handles", function(e)
		local m = e.model()
		local h = e.status:ApplyStatus(m, "A", true, 1)
		e.status:RemoveProfile(m)
		equal(e.status.Registry[m], nil)
		equal(m:GetAttribute("A"), nil)
		equal(h:GetRemainingTime(), 0)
		equal(e.jobs[1].cancelled, true)
		e.status:RemoveProfile(m)
	end)

	test("death and destruction release profiles", function(e)
		local m, humanoid = e.model()
		e.status:SetStatus(m, "A", true, 10)
		humanoid.Died:Fire()
		equal(e.status.Registry[m], nil)
		local n = e.model()
		e.status:SetStatus(n, "A", true, 10)
		n:Destroy()
		equal(e.status.Registry[n], nil)
	end)

	test("reparent preserves statuses and removal clears them", function(e)
		local m = e.model()
		e.status:SetStatus(m, "A", true, 10)
		m.AncestryChanged:Fire(m, {})
		equal(m:GetAttribute("A"), true)
		m.Parent = nil
		m.AncestryChanged:Fire(m, nil)
		equal(e.status.Registry[m], nil)
	end)

	test("invalid durations are rejected before mutation", function(e)
		local m = e.model()
		for _, duration in {-1, math.huge, 0/0} do
			local ok = pcall(function() e.status:SetStatus(m, "A", true, duration) end)
			equal(ok, false)
			equal(m:GetAttribute("A"), nil)
		end
	end)

	test("sprint and no-jump compose independently", function(e)
		local m = e.model()
		m:SetAttribute("IsSprinting", true)
		m:SetAttribute("NoJump", true)
		local value = e.status:ResolveProperties(m, {WalkSpeed=10, JumpPower=50})
		equal(value.WalkSpeed, 30)
		equal(value.JumpPower, 0)
		m:SetAttribute("IsStunned", false)
		equal(e.status:ResolveProperties(m, {WalkSpeed=10}).WalkSpeed, 30)
	end)

	test("equal-priority overrides choose the restrictive value", function(e)
		local value = e.resolver.Resolve({A=true, B=true}, {A={Priority=3, WalkSpeed=30}, B={Priority=3, WalkSpeed=8}}, {WalkSpeed=10})
		equal(value.WalkSpeed, 8)
	end)

	test("modifiers compose in a fixed order", function(e)
		local defs = {
			A={Modifiers={Speed={Operation="Add",Value=2}}},
			B={Modifiers={Speed={Operation="Multiply",Value=2}}},
			C={Modifiers={Speed={Operation="Min",Value=20}}},
			D={Modifiers={Speed={Operation="Max",Value=15}}},
		}
		equal(e.resolver.Resolve({D=true,B=true,A=true,C=true},defs,{Speed=10}).Speed,20)
	end)

	test("properties execute on attribute changes without changing rotation", function(e)
		local m, h, label = e.model()
		local c = e.controller(m, h)
		e.properties:InitCharacter(c)
		e.status:SetStatus(m, "IsSprinting", true)
		e.status:SetStatus(m, "NoJump", true)
		equal(h.WalkSpeed, 30)
		equal(h.JumpPower, 0)
		equal(h.AutoRotate, false)
		e.status:SetStatus(m, "IsStunned", true, 0.5)
		equal(h.WalkSpeed, 6)
		equal(label.Text, "IsStunned")
		e.clock.advance(0.5)
		equal(h.WalkSpeed, 30)
		equal(h.JumpPower, 0)
	end)

	test("old property timers cannot affect a replacement character", function(e)
		local m, h = e.model()
		local c = e.controller(m,h)
		e.properties:InitCharacter(c)
		h.Jumping:Fire(true)
		local old = e.jobs[#e.jobs]
		local n, nh = e.model()
		c.Character, c.Humanoid = n, nh
		e.properties:InitCharacter(c)
		nh.Jumping:Fire(true)
		equal(nh.JumpPower, 40)
		old.fn()
		equal(nh.JumpPower, 40)
	end)

	test("fractional cooldown query and expiry are numeric", function(e)
		local m = e.model()
		e.cooldown:ApplyCooldown(m,"Test",0.5)
		equal(e.cooldown:GetRemainingTime(m,"Test"),0.5)
		e.clock.advance(0.2)
		equal(e.cooldown:GetRemainingTime(m,"Test"),0.3)
		e.clock.advance(0.3)
		equal(e.cooldown:CheckCooldown(m,"Test"),false)
	end)

	test("cooldown batches and untracked removals work", function(e)
		local m = e.model()
		e.cooldown:ApplyCooldowns(m,{{Cooldown="A",Duration=1},{Cooldown="B",Duration=2}})
		equal(e.cooldown:CheckCooldowns(m,{"A","B"}),true)
		e.cooldown:RemoveCooldowns(m,{"A","B"})
		equal(e.cooldown:CheckCooldowns(m,{A=true,B=true}),false)
		m:SetAttribute("External_Timer","S:{100} D:{}")
		e.cooldown:RemoveCooldown(m,"External")
		equal(m:GetAttribute("External_Timer"),nil)
	end)

	test("indefinite cooldowns and zero duration are explicit", function(e)
		local m = e.model()
		e.cooldown:ApplyCooldown(m,"A")
		equal(e.cooldown:GetRemainingTime(m,"A"),math.huge)
		e.cooldown:ApplyCooldown(m,"A",0)
		equal(e.cooldown:CheckCooldown(m,"A"),false)
	end)

	test("queries recognize elapsed cooldowns before callback execution", function(e)
		local m = e.model()
		e.cooldown:ApplyCooldown(m,"A",0.1)
		e.clock.skip(1)
		equal(e.cooldown:CheckCooldown(m,"A"),false)
	end)

	test("cooldown cleanup preserves gameplay statuses", function(e)
		local m = e.model()
		e.status:SetStatus(m,"IsStunned",true,10)
		e.cooldown:ApplyCooldown(m,"A",1)
		e.cooldown:RemoveProfile(m)
		equal(m:GetAttribute("A_Timer"),nil)
		equal(m:GetAttribute("IsStunned"),true)
	end)

	test("destroyed actors invalidate cooldown timers", function(e)
		local m = e.model()
		e.cooldown:ApplyCooldown(m,"A",1)
		m:Destroy()
		equal(m:GetAttribute("A_Timer"),nil)
		equal(e.status.Registry[m],nil)
	end)

	return { passed = #passed, tests = passed }
end
