export type Evade = {
	range: number,
	safe: number,
	watch: number,
	watch_time: { number },
	distance: number,
	speed: string | number,
	refresh: number,
	startle: number,
	fan: { number },
	predators: { string },
}

export type SleepAnimations = {
	lie: string,
	loop: string,
	wake: string,
}

export type Sleep = {
	chance: number,
	wake_range: number,
	wake_speed: number,
	resettle: number | false,
	blend: number,
	animations: SleepAnimations,
}

export type Gait = {
	at: { number },
	shake: string,
}

export type Footsteps = {
	gaits: { [string]: Gait },
	range: number,
	min_weight: number,
}

export type Notice = {
	visual: string,
	emit: string?,
	head: string,
	offset: Vector3,
	cooldown: number,
	lifetime: number,
}

export type Confuse = Notice & {
	range: number,
}

export type Scatter = {
	distance: number,
	spread: number,
}

export type Gnaw = {
	animation: string,
	visual: string?,
	marker: string,
	damage: number,
	remaining: number,
	distance: number,
	gnawers: number,
	speed: string | number,
	scatter: Scatter,
}

export type Sneak = {
	notice: number,
	forget: number,
}

export type TempoStrafe = {
	time: { number },
	step: number,
	speed: string | number,
}

export type TempoBack = {
	distance: { number },
	speed: string | number,
}

export type TempoSetup = {
	ability: string,
	chance: number,
	margin: number,
	speed: string | number,
	hold: number,
}

export type Tempo = {
	flurry: { number },
	moves: { [string]: number },
	strafe: TempoStrafe,
	back: TempoBack,
	setup: TempoSetup | false,
}

export type Stance = {
	range: number,
	leave: number,
	enter: string,
	exit: string,
	enter_speed: number,
	exit_speed: number,
	blend: number,
}

export type Nip = {
	first: { number },
	every: { number },
	damage: number,
	animation: string?,
	visual: string?,
	windup: number,
	recovery: number,
	reach: number,
	speed: number,
	approach: number,
}

export type Lurk = {
	band: { number },
	nip: Nip,
}

export type Breather = {
	Kind: string,
	Side: number,
	Distance: number,
	Time: number,
}

return {}
