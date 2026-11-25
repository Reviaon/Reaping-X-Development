export type Ground = {
	Position: Vector3,
	Normal: Vector3,
	Material: Enum.Material,
	MaterialVariant: string,
	Color: Color3,
	Kind: string,
}

export type Foot = {
	Leg: BasePart,
	Peak: number,
	Armed: boolean,
}

export type Watch = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Feet: { Foot },
}

export type PebbleSettings = {
	Speed: number,
	Count: NumberRange,
	Size: NumberRange,
	Back: NumberRange,
	Up: NumberRange,
	Spread: number,
	Gravity: number,
	Lifetime: number,
	Shrink: number,
	Lift: number,
	Pool: number,
	PoolGrowth: number,
}

export type StepSounds = {
	Kinds: { [string]: string },
	RunSpeed: number,
	Mute: { string },
}

export type Config = {
	Assets: { string },
	Pebble: { string },
	Visuals: { string },
	Kinds: { [string]: string },
	Fallback: string,
	Materials: { [Enum.Material]: string },
	Legs: { string },
	Range: number,
	MinSpeed: number,
	Reach: number,
	Drop: number,
	Rearm: number,
	RayUp: number,
	RayDepth: number,
	Sounds: StepSounds,
	PrintPool: number,
	Pebbles: PebbleSettings,
}

return {}
