export type Source = {
	FadeIn: number,
	Speed: number?,
}

export type Config = {
	Animation: string,
	Priority: Enum.AnimationPriority,
	Speed: number,
	FadeOut: number,
	Release: number,
	FallbackLength: number,
	Status: string,
	StatusSource: string,
	TailAttribute: string,
	Tail: number,
	Sources: { [string]: Source },
}

return {}
