export type Slot = {
	Limb: string,
	Size: Vector3,
	Offset: CFrame,
}

export type FitConfig = {
	Margin: number,
	Edge: number,
	Rows: number,
	Columns: number,
	Rim: number,
	Wall: number,
	Facing: number,
	Reach: number,
	MaxScale: number,
}

export type Config = {
	Folder: string,
	Container: string,
	PiecePrefix: string,
	Attribute: string,
	BodyAttribute: string,
	ScaleAttribute: string,
	HideLimbs: boolean,
	HiddenAttribute: string,
	ShowLimbAttribute: string,
	Default: string?,
	OffWords: { [string]: boolean },
	Fit: FitConfig,
	Slots: { [string]: Slot },
}

export type Placed = {
	Source: BasePart,
	Slot: Slot,
	Offset: CFrame,
}

export type Fitted = {
	Source: BasePart,
	Slot: Slot,
	Offset: CFrame,
	Scale: Vector3,
}

export type Set = {
	Name: string,
	Pieces: { Fitted },
}

return {}
