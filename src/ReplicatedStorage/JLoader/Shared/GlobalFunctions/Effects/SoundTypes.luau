export type Entry = {
	Ids: { number },
	Volume: number?,
	PlaybackSpeed: number?,
	Looped: boolean?,
	StartAt: number?,
	Trim: { [number]: number }?,
	RollOffMaxDistance: number?,
	Cycle: boolean?,
	Numbers: { number }?,
}

export type Group = { [string]: Entry | Group }

export type PlayOptions = {
	Parent: Instance?,
	Position: Vector3?,
	Variant: number?,
	Number: number?,
	Owner: Instance?,
	Volume: number?,
	PlaybackSpeed: number?,
	Looped: boolean?,
	StartAt: number?,
	FadeIn: number?,
}

export type Tuning = {
	Volume: number?,
	PlaybackSpeed: number?,
}

export type Target = Sound | string | { Sound }

return {}
