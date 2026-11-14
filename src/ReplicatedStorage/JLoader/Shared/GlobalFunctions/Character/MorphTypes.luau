export type Hold = {
	attribute: string,
	from: string?,
	to: string?,
	visual: string?,
}

export type Shot = {
	animation: string,
	visual: string?,
	speed: number?,
	hold: Hold?,
}

export type DashTuning = {
	distance: number?,
	speed: number?,
	cooldown: number?,
}

export type BiteTuning = {
	lunge: number?,
	track: number?,
	cone: number?,
	range: number?,
}

export type Input = Enum.KeyCode | Enum.UserInputType

export type Entry = {
	mob: string?,
	walk_speed: number?,
	run_speed: number?,
	jump: number?,
	land_animation: string?,
	dash: DashTuning?,
	bite: BiteTuning?,
	leap_distance: { [string]: number }?,
	controls: { [string]: { Input } }?,
	abilities: { string }?,
	shots: { Shot }?,
}

export type AbilityResult = "Rejected" | "Interrupted" | "Missed" | "Landed"

export type Leap = {
	delay: number?,
	speed: number?,
	airtime: number?,
	max_speed: number?,
	lead: number?,
	track: number?,
	overrun: number?,
	settle: number?,
}

export type Ability = {
	name: string,
	label: string,
	animation: string?,
	miss_animation: string?,
	speed: number?,
	windup: number,
	recovery: number,
	cooldown: number,
	ability_cooldown: number,
	reach: number,
	range: number?,
	leap: Leap?,
}

export type Bite = {
	animation: string?,
	speed: number?,
	windup: number,
	recovery: number,
	cooldown: number,
	reach: number,
	reach_from: number?,
	radius: number,
	step_in: number?,
	final: boolean?,
	step_in_lead: number?,
	step_in_ease: number?,
	step_in_rise: number?,
	range: number?,
	miss_animation: string?,
	leap: Leap?,
}

export type Dash = {
	speed: number,
	playback: number?,
	recovery: number?,
	visual: string?,
	animations: { [string]: string }?,
}

export type ClientProfile = {
	mob: string,
	walk_speed: number,
	run_speed: number,
	animations: { [string]: string },
	animation_speeds: { [string]: number },
	exclusive: { { string } },
	hurt: { string },
	visuals: string?,
	combo_reset: number,
	combo: { Bite },
	abilities: { Ability },
	dash: Dash?,
}

return {}
