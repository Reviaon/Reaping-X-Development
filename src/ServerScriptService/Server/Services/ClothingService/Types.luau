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
	Slots: { [string]: string },
}

export type Placed = {
	Source: BasePart,
	Limb: string,
	Offset: CFrame,
}

export type Set = {
	Name: string,
	Pieces: { Placed },
}

return {}
