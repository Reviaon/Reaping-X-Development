local Players = game:GetService("Players")

local Jloader = require("@game/ReplicatedStorage/JLoader")
local MobTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MobTypes")

local EFFECT = "Combat.Notice"
local METHOD = "Emit"

local Notice = {}

local effectService = nil

local function effects()
	effectService = effectService or Jloader.GetService("EffectService")
	return effectService
end

function Notice.Show(mob, target: Model?): boolean
	local settings: MobTypes.Notice? = mob.Config.notice
	if not settings or not target or not Players:GetPlayerFromCharacter(target) then return false end

	local now = os.clock()
	local blackboard = mob.Blackboard

	if now - (blackboard.NoticedAt or -math.huge) < settings.cooldown then return false end

	blackboard.NoticedAt = now

	effects():SpawnVisual(nil, {
		Effect = EFFECT,
		Method = METHOD,
		Info = {
			Character = mob.Model,
			Visual = settings.visual,
			Head = settings.head,
			Offset = settings.offset,
			Lifetime = settings.lifetime,
		},
	})

	return true
end

return Notice
