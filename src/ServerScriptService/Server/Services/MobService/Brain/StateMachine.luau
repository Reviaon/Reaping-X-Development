local Tree = require("./Tree")
local InspectConfig = require("../Inspect/Config")

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(mob)
	return setmetatable({
		Mob = mob,
		Name = nil,
		State = nil,
		Data = nil,
		EnteredAt = 0,
	}, StateMachine)
end

function StateMachine:IsLocked(): boolean
	local state = self.State
	return state ~= nil and state.Locked ~= nil and state.Locked(self.Mob, self.Data) == true
end

function StateMachine:IsDone(): boolean
	local state = self.State
	return state ~= nil and state.Done ~= nil and state.Done(self.Mob, self.Data) == true
end

function StateMachine:Request(name: string, args, force: boolean?): boolean
	if self.Name == name and not self:IsDone() then return true end
	if not force and self:IsLocked() then return false end

	self:Leave()

	local state = Tree.States[name]

	self.Name = name
	self.State = state
	self.Data = {}
	self.EnteredAt = os.clock()

	self.Mob.Model:SetAttribute(InspectConfig.StateAttribute, name)

	if state.Enter then
		state.Enter(self.Mob, self.Data, args)
	end

	return true
end

function StateMachine:Update(dt: number)
	local state = self.State
	if not state or not state.Update then return end

	state.Update(self.Mob, self.Data, dt, os.clock() - self.EnteredAt)
end

function StateMachine:Exit()
	if not self.State then return end

	self:Leave()
	self.Mob.Model:SetAttribute(InspectConfig.StateAttribute, nil)
end

function StateMachine:Leave()
	local state = self.State
	if not state then return end

	self.Name = nil
	self.State = nil

	if state.Exit then
		state.Exit(self.Mob, self.Data)
	end

	self.Data = nil
end

return StateMachine
