export type Data = { [string | number]: any }

export type Profile = {
	Data: Data,
	AddUserId: (Profile, number) -> (),
	Reconcile: (Profile) -> (),
	ListenToRelease: (Profile, (string?, string?) -> ()) -> any,
	Release: (Profile) -> (),
	IsActive: (Profile) -> boolean,
}

export type ProfileStore = {
	LoadProfileAsync: (ProfileStore, string) -> Profile?,
	Mock: ProfileStore,
}

export type Store = {
	Name: string,
	Template: Data,
	Replicate: string?,
}

export type Config = {
	Prefix: string,
	MockInStudio: boolean,
	Stores: { [string]: Store },
	Classes: { [string]: string },
	Kick: {
		Failed: string,
		Released: string,
	},
}

export type Session = {
	Profile: Profile,
	Folder: Folder?,
}

export type Handler = (Player, Profile) -> ()

return {}
