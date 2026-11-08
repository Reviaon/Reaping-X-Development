local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")

export type Settings = {
	StashName: string,
	StrikeTolerance: number,
	MaxVictims: number,
	EarlyStrike: number,
	LateStrike: number,
	SwingSlack: number,
}

export type Spec = {
	windup: number,
	recovery: number,
	cooldown: number,
	reach: number,
	reach_from: number?,
	radius: number,
	damage: number,
	[string]: any,
}

export type Config = {
	health: number,
	walk_speed: number,
	run_speed: number,
	attack: { [string]: any },
	[string]: any,
}

export type Kind = {
	Name: string,
	Config: Config,
	Prototype: Model,
	[string]: any,
}

export type Profile = {
	Name: string,
	Entry: MorphTypes.Entry,
	Kind: Kind,
	Config: Config,
	Specs: { Spec },
	Abilities: { [string]: Spec },
	AbilityOrder: { string },
	Holds: { [string]: boolean },
	Json: string,
}

export type Swing = {
	Index: number,
	Spec: Spec,
	At: number,
	Landed: boolean,
}

export type Use = {
	Name: string,
	Spec: Spec,
	At: number,
}

export type Morph = {
	Name: string,
	Profile: Profile,
	Model: Model,
	Player: Player,
	Swing: Swing?,
	Ability: Use?,
	ReadyAt: { [string]: number },
	Tools: { [string]: Tool },
	Guards: { RBXScriptConnection },
}

return {}
