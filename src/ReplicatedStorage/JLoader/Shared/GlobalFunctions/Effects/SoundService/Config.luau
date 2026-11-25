--[[@
	**SoundService config**: where sounds are found and how they play when an entry leaves a setting out
	- **Library:** `ReplicatedStorage.Libraries.<Library>`; a sound's path is its folders, module and keys joined by `Separator`
	  - e.g. `Weapons/Dagger.luau`'s `Hit` is `Weapons.Dagger.Hit`
	- **Defaults:** fill whatever neither the entry nor the `Play` call sets
	- **Groups:** one `SoundGroup` per top-level library folder, so a whole category turns up or down together
	  - Made on clients only, for sounds that client plays; a category missing here starts at 1
	  - A `SoundGroup` already in `SoundService` with the category's name is used instead of making one
]]
return {
	Library = "SoundLibrary", --@ Folder under ReplicatedStorage.Libraries
	Separator = ".", --@ Joins path segments

	Defaults = {
		Volume = 0.5, --@ Roblox Sound volume, 0–10
		PlaybackSpeed = 1, --@ Speed and pitch multiplier
		RollOffMinDistance = 8, --@ Studs a placed sound stays at full volume
		RollOffMaxDistance = 90, --@ Studs past which a placed sound is silent
	},

	Groups = {
		Footsteps = 1, --@ SoundGroup volume per category
		Weapons = 1,
		Abilities = 1,
		Mobs = 1,
	},

	AvoidRepeat = true, --@ A random pick never repeats the variant that path played last
}
