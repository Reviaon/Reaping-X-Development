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

export type SaveConfig = {
	Scope: string,
	Path: { string },
	Key: string,
	Timeout: number,
}

export type Config = {
	Folder: string,
	Container: string,
	PiecePrefix: string,
	Centre: string,
	ScaleAttribute: string,
	HideLimbs: boolean,
	HiddenAttribute: string,
	ShowLimbAttribute: string,
	Default: string?,
	OffWords: { [string]: boolean },
	Save: SaveConfig,
	StripAvatar: boolean,
	StripClasses: { string },
	KeepTypes: { Enum.AccessoryType },
	KeepAttachments: { string },
	Fit: FitConfig,
	Slots: { [string]: string },
}

export type Placed = {
	Source: BasePart,
	Limb: string,
	Base: Vector3,
	Offset: CFrame,
}

export type Fitted = {
	Source: BasePart,
	Limb: string,
	Base: Vector3,
	Offset: CFrame,
	Scale: Vector3,
}

export type Set = {
	Name: string,
	Pieces: { Fitted },
}

return {}
