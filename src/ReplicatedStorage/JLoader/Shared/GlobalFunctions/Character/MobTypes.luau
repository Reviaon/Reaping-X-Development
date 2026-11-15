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
	head: string,
	offset: Vector3,
	cooldown: number,
	lifetime: number,
}

return {}
