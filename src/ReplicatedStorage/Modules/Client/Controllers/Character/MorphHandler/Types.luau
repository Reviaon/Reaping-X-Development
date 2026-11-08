local MorphTypes = require("@game/ReplicatedStorage/JLoader/Shared/GlobalFunctions/Character/MorphTypes")

export type Entry = MorphTypes.Entry
export type Profile = MorphTypes.ClientProfile
export type Input = MorphTypes.Input
export type Shot = MorphTypes.Shot
export type Hold = MorphTypes.Hold
export type BiteSpec = MorphTypes.Bite
export type DashTuning = MorphTypes.DashTuning
export type Ability = MorphTypes.Ability

export type ClipPlayer = {
	Track: (self: ClipPlayer, key: string) -> AnimationTrack?,
	Play: (self: ClipPlayer, key: string, speed: number?) -> AnimationTrack?,
	Loop: (self: ClipPlayer, key: string, priority: Enum.AnimationPriority) -> AnimationTrack?,
	Playing: (self: ClipPlayer, key: string) -> AnimationTrack?,
	Stop: (self: ClipPlayer, key: string?, fade: number?) -> (),
	StopAll: (self: ClipPlayer, fade: number?) -> (),
	Destroy: (self: ClipPlayer) -> (),
}

export type Burst = {
	Start: (self: Burst, velocity: Vector3, duration: number) -> (),
	Steer: (self: Burst, velocity: Vector3) -> (),
	Stop: (self: Burst) -> (),
	Destroy: (self: Burst) -> (),
}

export type Jump = {
	Decayed: number,
	Pending: boolean,
	Launching: boolean,
}

export type DashMotion = {
	Direction: Vector3,
	Speed: number,
	Playback: number,
	Side: string,
	At: number,
	Until: number,
}

export type LeapMotion = {
	Target: BasePart?,
	Landing: Vector3?,
	Direction: Vector3,
	Speed: number,
	Lead: number,
	Reach: number,
	Homing: boolean,
	Arrived: boolean,
	At: number,
	Until: number,
}

export type State = {
	ClearAt: { [string]: number },
	Jump: Jump,
	Locomotion: string?,
	Combo: number?,
	BiteAt: number?,
	BiteHeld: boolean?,
	BiteAnimation: string?,
	NextBiteAt: number?,
	DashAnimation: string?,
	DashReadyAt: number?,
	Dash: DashMotion?,
	Leap: LeapMotion?,
	BusyUntil: number?,
	Attacking: boolean?,
	StepIn: number?,
	Running: boolean?,
	Ability: string?,
	AbilityAnimation: string?,
}

export type Session = {
	Name: string,
	Entry: Entry,
	Profile: Profile,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Service: any,
	Trove: any,
	State: State,
	Threads: { [string]: { thread } },
	Stepping: { [Action]: boolean },
	Tools: { [Tool]: string },
	WalkSpeed: number,
	RunSpeed: number,
	JumpPower: number,
	Destroyed: boolean,
	Animator: ClipPlayer,
	Burst: Burst,

	Start: (self: Session) -> (),
	Speed: (self: Session) -> (),
	Yielded: (self: Session) -> boolean,
	Busy: (self: Session, now: number) -> boolean,
	Look: (self: Session) -> Vector3,
	Delay: (self: Session, group: string, seconds: number, callback: () -> ()) -> (),
	Cancel: (self: Session, group: string) -> (),
	Interrupt: (self: Session) -> (),
	Halt: (self: Session) -> (),
	Destroy: (self: Session) -> (),
}

export type Action = {
	Began: ((session: Session, argument: number?) -> ())?,
	Ended: ((session: Session, argument: number?) -> ())?,
	Step: ((session: Session) -> ())?,
}

return {}
