# Reaping-X

Luau source for the Roblox place **Development Place** (`placeId 75090379520052`). The place is in
Team Create; `src/` is synced into it with Rojo.

- [Getting set up](#getting-set-up)
- [What is NOT in this repository](#what-is-not-in-this-repository)
- [How the game boots](#how-the-game-boots)
- [Services and handlers](#services-and-handlers)
- [Controllers](#controllers)
- [Adding a handler](#adding-a-handler)
- [Adding a component](#adding-a-component)
- [Adding a service](#adding-a-service)
- [Adding a weapon](#adding-a-weapon)
- [Combat](#combat)
- [Effects](#effects)
- [The console](#the-console)
- [Known rough edges](#known-rough-edges)

---

## Getting set up

Tools are pinned in `aftman.toml`. Install [Aftman](https://github.com/LPGhatguy/aftman), then:

```
aftman install
rojo serve
```

Connect the Rojo plugin from inside Studio with the place open.

**`rojo serve` reads `default.project.json` once, at startup.** Adding a new top-level branch to that
file does not reach the place until you restart the server. A live-synced Rojo showing none of a new
branch is almost always this, not a broken connection. Editing files under a branch it already knows
syncs normally without a restart.

To check what is actually being served:

```
GET http://127.0.0.1:34872/api/rojo   ->  projectName must read "Reaping-X"
```

The response is MessagePack, so read it as bytes rather than JSON. Port 34872 is also the Rojo
default for the other Roblox projects on this machine, and only one can hold it at a time.

---

## What is NOT in this repository

**A fresh clone plus `rojo build` does not produce a working game.** Several things live only in the
place file and are invisible to git. Know this before you go looking for something that is not there:

| Missing | Why it matters |
| --- | --- |
| `ReplicatedStorage.Storage` | Mapped `$className`-only. Rigs, weapon models, `Models.RigParts.Handle`, particles, animations and `UIFolder` all live here. |
| `Workspace` | Not mapped at all. The map, `World.Live` (where characters are parented) and the NPC placements are place-only. |

Practical consequence: inspect the live place through Studio rather than reasoning from `src/`, and
do not assume something is absent just because grep found nothing.

---

## How the game boots

**Server** — `ServerScriptService/Core/init.server.luau`

```lua
JLoader.LoadServices({ ServerScriptService.Server.Services })
JLoader.Load()
```

Every ModuleScript directly inside `Server/Services` is registered as a service.

**Client** — `StarterPlayer/StarterPlayerScripts/Core/init.client.luau`

Walks `ReplicatedStorage.Modules.Client` recursively **through Folders only**, collecting every
ModuleScript it finds as a handler, then appends `ReplicatedFirst.Modules.ClientEffects`.

It never descends into a ModuleScript. That distinction is what keeps a handler's own children
private: `CombatHandler` is a directory-form ModuleScript, so its `Config` and `@Components` are not
picked up as handlers in their own right. Group handlers into as many nested folders as you like;
just do not expect anything inside a handler to be auto-registered by the bootstrap.

`JLoader` itself resolves per environment: on the client it **destroys `JLoader.Server`** and returns
the client module. Requiring JLoader from a tool that runs in the Edit data model will therefore
delete `JLoader.Server` out of the open place. Do not do it.

---

## Services and handlers

Server code is a **service**, client code is a **handler**. They are separate concepts —
`Server.CreateHandler`, `InitHandler` and `GetHandler` exist only as stubs and do nothing.

```lua
local Jloader = require(game.ReplicatedStorage.JLoader)

local MyHandler = Jloader.CreateHandler({
    Name = script.Name,
    Priority = 1,          --@ Higher loads first. Default 1
    Signals = { "Ready" },  --@ Each name becomes a Signal on the handler
})
```

```lua
local MyService = Jloader.CreateService({
    Name = script.Name,
    Priority = 1,
    Signals = { Basic = {...}, Remote = {...}, Hybrid = {...} },
    Shared = {},            --@ Functions here are callable by clients over RPC
})
```

### Lifecycle

Methods are optional; define only the ones you need.

| Method | When |
| --- | --- |
| `Init(self)` | Once, at load. Runs again only if `AllowReinit` is set, and `Clean` is called first. |
| `Load(self)` | Once, after every service/handler has been initialised. Spawned, so it may yield. |
| `InitPlayer(self, player, isLocal)` | Per player. |
| `InitCharacter(self, controller, isLocal)` | Per character spawn — **for every player, not just this one**. See below. |
| `Clean(self)` | Before a re-`Init`. |

Everything is sorted by `Priority` descending before `Load` runs.

**On the client, `InitCharacter` only fires for this player's own character.** Handlers that want
every character — footsteps, nameplates, anything cosmetic on other players — opt in:

```lua
local MyHandler = Jloader.CreateHandler({
    Name = script.Name,
    RemoteCharacters = true,
})
```

An opted-in handler is then handed a **raw `Character` Model** for remote characters, since
`controllerFactory` only builds a controller for the local one. Use the `isLocal` argument to tell
them apart:

```lua
function MyHandler:InitCharacter(controller, isLocal)
    local character = isLocal and controller.Character or controller
```

The server has no local character, so a service's `InitCharacter` always runs and always receives
the raw Character.

`Signals` on a service are more than local events. A `Remote` or `Hybrid` signal is keyed by the
channel string `ServiceName|Type|SignalName` and routed through the shared ByteNet namespace — there
is no per-signal RemoteEvent. The client recomputes the same string, which is how the two ends meet.
Only names declared in `Shared` are reachable by RPC.

---

## Controllers

A **controller** is the object a handler is handed for one character. It is the main thing to
understand, because nearly every gameplay call takes one.

|  | Client | Server |
| --- | --- | --- |
| Object | `ClientController` (singleton, local character only) | `CharacterProfile` (one per character) |
| Get it from | `InitCharacter(controller)` | `ServerController:GetProfile(character)` |

Both expose the same surface, deliberately:

```lua
controller.Character          --@ and .Humanoid, .HumanoidRootPart, .Player
controller:Get(key)           --@ and :Set, :Remove, :Update
controller.HitboxService      --@ any GlobalFunctions module, resolved lazily
controller.foo = value        --@ writes land in the controller's State table
```

That last line is the part that surprises people. Both controllers have a `__newindex` routing
writes into an internal `State` table, and an `__index` that resolves **methods, then State, then
`GlobalFunctions`**. So `controller.AttackService` is not a field anybody assigned — it is the
`GlobalFunctions` fallback finding `Service/AttackService.luau` by name.

`GlobalFunctions` is a lazily-populated registry keyed by module name. Drop a module in
`JLoader/Shared/GlobalFunctions/Service/` and it is reachable as `controller.<ModuleName>` from both
sides, with no registration step.

**Every profile has an id.** `profile.Id` is unique per profile instance and readable —
`Player_Sizzorsx_1`, `NPC_Dummy_4` — and is mirrored onto the character as a `ProfileId` attribute,
so it shows in the Explorer and can be read without the profile. Look one up with
`ServerController:GetProfileById(id)`.

It identifies a *profile*, not a person: a respawn is a new character and a new profile, so anything
keyed on one stops referring to the old character rather than silently following the new one. Use it
wherever you need a stable key for a character — do **not** reach for `GetDebugId`, which is a
plugin-only API and throws from a game thread.

**NPCs get a profile too.** Anything with a Humanoid parented into `workspace.World.Live` that is
not a player's character is adopted by `GameService` and given the same `CharacterProfile` a player
gets — so a console-spawned Dummy is a real controller, with `:Get`/`:Set`, the `GlobalFunctions`
fallback, its own `Scope` namespaces and a Trove that dies with it.

Adoption also calls `AnimatorService:EnsureAnimator`, because rig templates are not all authored
with an `Animator` and nothing animates without one. It has to happen **on the server**: an
`Animator` created on a client exists only on that client, so a rig would animate for one player and
stand still for everyone else. Animation-playing code should ask `AnimatorService:GetAnimator`
rather than reaching for the instance itself — the shared lookup warns once per rig when there is
none, which is the difference between a diagnosable bug and animations that silently never play.

> **Caveat, client side only.** `controllerFactory` returns the raw `Character` **Model** for a
> character that is not the local player's, so a client handler's `InitCharacter` receives a Model
> for remote players. A Model has no `:Set` and no `GlobalFunctions` fallback. In practice those
> handlers read `controller.Character` first and bail, but do not assume a controller on that path.
> NPC logic should use the server-side profile instead.

### Per-controller state

Do **not** hold per-character state in module-level locals. A handler module is required once, so two
characters in one data model share every `local` at the top of the file — one character's cleanup
tears down the other's. Use the controller instead:

```lua
local SCOPE = "MyThing"

local function doSomething(controller)
    local state = controller:Scope(SCOPE)
    state.track = track
end
```

`controller:Scope(namespace)` is namespaced scratch space on the controller itself, on both sides.
It is cleared with the character, so each life starts clean — call it at the point of use rather
than caching the table, or a closure will hold a scope from a previous life.

Two things are deliberately left at module scope, and are the exception rather than the pattern: a
pure lookup cache whose answer is the same for every character (`IdleComponent._animationExists`),
and `CameraHandler._influenceLevel`, since a client has exactly one camera.

---

## Adding a handler

1. Create `ReplicatedStorage/Modules/Client/Controllers/<Group>/MyHandler.luau`, or a directory with
   `init.luau` if it needs children.
2. `Jloader.CreateHandler({ Name = script.Name })`, define lifecycle methods, `return` it.

That is all — the bootstrap finds it. Groups are `Camera/`, `Character/` and `System/`; add a folder
if none fits.

---

## Adding a component

Components are ModuleScripts in an **`@Components` folder inside the handler**, loaded by that
handler rather than by the bootstrap:

```lua
MyHandler.components = Jloader.GlobalFunctions.Components.Load(script)
```

Drop the module in `@Components/` and it is loaded, keyed by its name. Anything else in the handler
— a `Config`, a helper — is left alone by virtue of not being in that folder. A module that fails to
require warns and is skipped rather than taking the handler down.

Combat components implement `CanActivate`, `Activate`, `Deactivate` and optionally `Init`, all taking
`(controller, combatState)`. `CombatHandler:BeginBranch` resolves them by name as
`<Branch>AttackComponent`.

Use `AttackService` rather than hand-rolling swing plumbing:

```lua
local AttackService = controller.AttackService

local track = AttackService:SwapTrack(controller, KEY, character, animationName, properties)
AttackService:ScheduleEaseOut(controller, KEY, track, timing)
AttackService:ScheduleHitbox(controller, KEY, character, timing, { weaponId = weaponId })
AttackService:ScheduleImpulse(controller, KEY, character, timing)
AttackService:CancelSwing(controller, KEY)   --@ cancels all of the above
```

`KEY` is one string per swing. The service namespaces its own sub-keys underneath it, so the three
schedules cannot cancel each other.

---

## Adding a service

Create `ServerScriptService/Server/Services/MyService.luau`, `Jloader.CreateService({...})`, `return`
it. Only direct children of `Services` are registered — a subfolder is not walked.

A shared utility that both sides need is not a service. Put it in
`JLoader/Shared/GlobalFunctions/Service/` and reach it as `controller.MyThing`.

---

## Adding a weapon

Three things must agree on one name — say `Sword`:

1. `ReplicatedStorage/Libraries/WeaponsLibrary/Sword.luau` — the config below.
2. The `Tool.Name` handed to the player.
3. The animation prefix: `SwordIdle`, `SwordAttack1` … `SwordAttack{N}`.

A `Tool` is only an identity marker. It carries an **invisible Handle** cloned from
`Storage.Models.RigParts.Handle`; the visible weapon is transplanted onto the character by
`ServerController:ApplyRig`, which fires on `Character.ChildAdded` and reads `Tool.Name`.
`RequiresHandle` defaults true, so a Tool without a Handle can never be equipped — and the rig path
only runs on equip, so it silently never runs at all.

`WeaponsLibrary` is resolved with `GetDescendants`, so weapons may be grouped into subfolders.

```lua
return {
    Rig = "SwordRig",              --@ Model under Storage.Rigs. nil = no geometry
    RigAttachments = { "Spin" },   --@ Rig attachments carried onto the character limb
    MaxCombo = 4,

    attack_speed = 1,              --@ Number, or a table keyed by combo index
    attack_cooldown = 0.5,
    attack_cooldown_final = 2,     --@ Used on the last combo instead
    attack_duration = { 0.733, 0.850, 0.750, 2 },

    ease_out = 0.1,                --@ Decelerate the tail of the swing
    ease_pause = 0.05,
    ease_fade = 0.25,

    light_impulse = {
        speed = 8, duration = 0.8, falloff = 0.5,
        priority = 1,              --@ A live higher-priority impulse cannot be stomped
        influence = 0.65,          --@ Share of walk speed that stays live during the push
        impulse = { {...}, {...} },      --@ Optional per-combo override
        impulse_delay = { 0.45, 0.55, 0.383, 0.25 },
    },

    --@ The victim's shove. Omit it entirely and it mirrors the attacker's own step above.
    knockback = {
        speed = 8, duration = 0.8, falloff = 0.5,
        priority = 1,
        knockback = { [4] = { speed = 20, duration = 1.2 } },  --@ Per-combo, same as the others
    },

    hitbox = {
        shape = "Box",             --@ Box, Sphere or Cylinder
        size = Vector3.new(6, 5, 7),
        offset = Vector3.new(0, 0, -4),
        duration = 0.1,
        max_targets = -1,
        effect = "BladeHit",       --@ Impact particle under CombatVFX.Hit
        hitbox = {                 --@ Per-combo overrides, inheriting anything not restated
            [4] = { size = Vector3.new(9, 6, 9), hitbox_delay = 0.8 },
        },
    },
}
```

Notes that are not obvious:

- **`size` is one Vector3 whatever the shape.** `Box` and `Cylinder` read all of it (the cylinder
  takes radius from X and height from Y); `Sphere` uses X as the radius.
  `CombatConfig:BuildHitboxData` does the translation, so a weapon can change shape without changing
  which key it authors.
- **The hitbox fires on the impulse cue** unless the block sets its own `hitbox_delay` — a number or
  a table keyed by combo at the top level, or a number inside a per-combo entry, which wins for that
  hit.
- **Keep `offset.Z` at roughly half of `size.Z`** so the near edge stays on the character and reach
  reads off `size.Z` alone.
- **Timings are authored at 1x.** `attack_speed` divides `attack_duration`, the cooldowns, the
  `ease_*` values, `impulse_delay`, the impulse `duration`/`falloff` and the hitbox `duration`; it
  multiplies impulse `speed`; it does not touch `influence` or `priority`.
- **A typo'd key is silent.** `ResolveNumber` falls back to a default on an unknown or wrongly-typed
  value, so `attack_duraton` produces default timing and no warning. Check spelling against this list
  before assuming a weapon is misbehaving.

---

## Combat

Flow of one light attack:

```
input -> CombatHandler:BeginBranch -> LightAttackComponent:Activate
      -> CombatConfig:ResolveAttackTiming      one resolve, everything scaled
      -> AttackService:SwapTrack               animation
      -> broadcastVisual                       weapon VFX, relayed
      -> AttackService:ScheduleHitbox          at impulse cue
      -> AttackService:ScheduleImpulse         lunge
```

`HitboxService` (Voided's library, vendored under `GlobalFunctions/Service`) polls every
`PreSimulation` until `Dispose`, so lifetime is a scheduled `Dispose` rather than a one-shot query.
Two constraints worth knowing before calling it directly:

- **A whitelist is mandatory.** Its default is `workspace:WaitForChild("Living")`, and this place has
  no `Living` — that call never returns. Pass `workspace.World.Live`.
- **`ActivationTime` is unusable from outside**, since it compares against a clock internal to the
  module. Schedule with `task.delay` instead.

Detection runs on the **attacker's client**; the victim's knockback runs on the **server**.

The attacking client reports the hit to `CombatService` over `ReportHit`, carrying the victim, the
weapon id and the combo index — identifiers, not physics — plus its own root CFrame at the moment of
detection. The server resolves the knockback from the weapon config itself and applies it, so a
tampered client can lie about *who* it hit but not about how hard. It has to be server-side
regardless: the victim is not the attacker's to move, since an NPC is owned by the server and
another player owns their own character.

Reports are dropped if the victim is not a Humanoid Model inside `workspace.World.Live`, is the
attacker itself, is further than `MaxReportDistance`, or repeats within `ReportCooldown`.

### How a knockback moves

A knockback is **not physics**. It is a recipe the server decides once and every machine evaluates
for itself — a start, a finish, a curve and a server-time clock — so every client draws the same
motion at the same moment instead of one machine simulating it and everyone else watching a
delayed replica. This is how combat games keep hit reactions in step, and it is the thing physics
replication structurally cannot do.

`KnockbackService` is the whole of it, shared, so the server and every client run the same code:

- **`Build`** (server) turns a direction and the weapon's knockback config into a recipe. The start
  is the previous knockback evaluated at this instant if one is still running — a chain stays
  deterministic because a trajectory is a pure function of time and nobody has to be asked where
  the victim is — otherwise the reference position. The finish is `start + direction × distance`,
  **blockcast against the map before anyone is told**, so a wall clamps it once, on the server,
  and every client agrees; letting clients raycast locally would desync under StreamingEnabled
  where a far client may not have the wall loaded. `distance` comes from the per-weapon config or,
  absent that, from integrating the same `speed/duration/falloff/rampIn` curve the physics version
  used, so existing tuning carries over.
- **`Evaluate`** is the pure function: recipe + time → horizontal position and how far through the
  facing turn it is. The curve is integrated at a fixed `CurveSamples` on every machine, so every
  machine lands on identical numbers.
- **`Apply`** records the recipe and, where this machine should drive, moves the character every
  frame. Every client draws every victim. The server drives only NPCs, so it must own them: left to
  Roblox, a nearby player's client owns them and fights the server's writes. A one-time
  `SetNetworkOwner(nil)` does not hold. **Welding any part onto an assembly resets it to
  automatic**, and the nearest player takes the NPC a frame later. The ragdoll colliders built
  during adoption do this, and so does every weapon Tool equip. So `GameService` runs a Heartbeat
  guard that re-claims every NPC root in `Live` whose ownership has fallen back to automatic. Without
  it a fresh dummy "warms up": its first knockbacks come up short and wander off the path until its
  first ragdoll happens to re-claim it. Adoption also disables the Humanoid's `FallingDown` state
  on NPCs. A freshly cloned Humanoid often trips into it on its first frame and then won't walk for
  3 seconds. Nothing in the game uses that state, since the ragdoll uses `Physics`. How each side
  moves the character is the whole trick, below.

Three details are what make it hold together:

- **Server time, not packet arrival.** `startTime` is `workspace:GetServerTimeNow()` and every
  frame computes `elapsed` from it, so a client that gets the packet late *joins the motion in
  progress* rather than starting from zero. Start on arrival and every client is offset by its own
  latency — the original problem in a new coat.
- **X/Z only; Y stays live — except over rising ground.** Each write keeps whatever Y physics or
  replication has, so drops off ledges and gravity stay with physics and no client has to solve Y.
  The one exception is ground that rises under the push: with `WalkSpeed` at 0 the Humanoid's own
  step-up does not engage, so the drive probes the ground at each new X/Z and **lifts** the root to
  keep its standing height. It only ever lifts — level or falling ground returns nothing — and a rise
  taller than `MaxStepUp` in a frame is a wall the blockcast should already have stopped short of.
  The rig's standing height (`groundOffset`) is measured once in `Build` and shipped in the recipe,
  so every client follows the slope by the same amount; a victim hit while airborne gets no
  `groundOffset` and Y is left alone for that knockback. `FollowGround` turns it off.
- **The owner moves; everyone else tops up replication.** The owner steps the curve on top of
  wherever it actually is through a `LinearVelocity` constraint (`DriveForce`), with its own walk
  folded in by `VictimInfluence`, so a stunned victim can still shuffle at the stun's `WalkSpeed`,
  a push never yanks them back to the server's slightly stale start, and — because velocity is what
  replicates — other clients receive a smoothly moving body rather than CFrame snaps. Each step is
  blockcast like the lunge's; rising ground lends the constraint its Y axis for the lifting frame;
  the facing turn is an `AlignOrientation` (`FacingResponsiveness`) for the same replication reason.
  A non-owner **never writes the root**: a root a client writes stops receiving replication until
  the writes stop, which is what produced every release pop. It leaves the physical root to
  replication and offsets the *body* through the root `Motor6D` by
  `curve(t) − curve(t − ReplicationLag)`: before the push reaches the replicated stream that is the
  whole push so far, while it runs it is exactly the slice replication has not delivered, and once
  the push has fully arrived it is zero — so the owner's walking arrives through replication
  underneath, the push is drawn current, and there is no handoff to blend and nothing to pop at
  release. The only error is `ReplicationLag` being wrong for a pair of clients, which shows as a
  slight over- or under-draw *during* the push, never a jump at the end. The facing turn is drawn
  the same way, as a yaw offset that shrinks as the replicated rotation catches up.
- **Nothing welded onto a character may carry mass.** The attacker's replication was observed to
  stall for ~0.1s and then jump on every other client, only on swings whose weapon visual had a
  non-massless part: the visual is welded to the root, so the character's assembly mass changed
  mid-lunge. `EffectService:Weld` now forces every part of an effect it attaches to be massless,
  unanchored and non-colliding, so an authoring slip in an asset cannot do this again.
- **The owner's constraints persist.** The `LinearVelocity` (tagged `DriveAttribute`) and the
  facing `AlignOrientation` are created once per root, re-aimed by each recipe, and parked
  (`Enabled = false`, priority cleared) between drives rather than rebuilt, so a chained combo
  changes nothing about the assembly. Anything that reads `PhysicsService.GetImpulse` must check
  `Enabled`, as `TiltComponent` does. A foreign mover on the root — the dive's — is still cleared.

The facing turn is part of the recipe: yaw slerps toward the attacker over the first
`FacingPortion` of the duration. Arbitration survives — the drive stamps `knockback_priority` and
`knockback_until` on the root, and `ApplyImpulse` refuses an impulse at or below that priority
while they are live. The dive builds its own mover rather than going through `ApplyImpulse`, so it
asks `KnockbackService.Active` itself: it will not start while a knockback at or above its priority
runs, and a stun or knockback landing during its wind-up or dash ends it. `CombatConfig:ClearImpulse`
cancels only the character's own steered lunge, never a server knockback, so neither a dive nor a
weapon swap can escape one.

### The attacker's lunge is the same recipe

The forward step a light attack takes is the same recipe. `AttackService` schedules
`KnockbackService.Lunge`, which composes one from the weapon's impulse config and drives it on the
attacker's own client (or on the server, for an NPC it owns) through a `LinearVelocity` constraint
fed the curve's per-frame velocity.

**Everyone else is told too.** Physics replication of a client-owned character — 20Hz snapshots
through an interpolation buffer — cannot carry a 0.2–0.8s burst without stepping, however the
owner produces it; observers saw the attacker stand still and pop to where the step ended. So at the
cue the attacker's client reports `(weaponId, comboIndex, direction)` over `ReportLunge`;
`CombatService` rebuilds the impulse from the weapon config (identifiers only, never the client's
numbers), composes a **non-steered projection** from the attacker's reference position, and
`FireExcept`s it to every other client on the same `Knockback` channel a shove uses. Observers draw
it exactly as they draw a victim — the un-replicated slice of the projection on top of the
replicated position — so whatever steering the attacker actually did arrives through replication
underneath it. An NPC's lunge is broadcast by the server the same way.

The point is stud alignment. A knockback that names no curve of its own takes the attacker's
impulse curve wholesale — `speed`, `duration`, `falloff`, `rampIn`, `distance` — so the shove and
the step that delivered it integrate to the **same distance by construction**, sample for sample.
Attack speed scales `speed` up and `duration`/`falloff`/`rampIn` down on both sides together, which
leaves that distance invariant. A weapon that wants the shove longer than the step sets one on the
knockback explicitly.

The lunge is **steered**, and that is deliberate. Only the victim's shove has to be deterministic —
every client draws it. The lunge is drawn by one machine, the attacker's, so it is free to respond
to input: the curve's speed is spent along the character's *live* look each frame rather than a
line fixed at the cue, and their own walking is folded in by `influence` (walk velocity × the
weapon's factor). `AutoRotate` is left on for it, because the Humanoid turning the root toward the
move direction is exactly what steers it. Holding the attacker rigidly on a line for the swing read
as clunky, and an attacker who moves while attacking was never going to stand still to stay
aligned with their victim.

So the alignment claim is precise: with **no input**, step and shove cover identical studs. With
input, the attacker deviates by their own choice. A steered recipe has no fixed finish to clamp, so
it blockcasts the step it is actually about to take every frame instead; and because its path is
not a function of time, a knockback or lunge chained after it starts from the live root rather than
from an evaluation.

Arbitration between a lunge and a knockback on the same character goes by `priority`: equal or
higher replaces, lower is refused while the current one is still running. Server recipe ids only
order server recipes against each other, so a client-built lunge never blocks a knockback the
server sends for that character.

The attacker still learns of the *victim's* recipe one hop late. Because it is a pure function of
the attacker position, the victim position and the weapon config — all of which the attacker's
client has at detection — it could start the identical motion immediately and reconcile when the
server's copy lands; that is a follow-up once the base is verified in play, not part of this.

### Ruled out

Network ownership is **not** transferred. Three variants were tried, recorded here so they are not
tried again blind:

- **Handing the victim's root to the attacker** made the attacker's swing land immediately, but the
  handback jittered the victim, and a combo degraded further with every hit. Tightening the hold
  reduced it but could not remove it, because a client that does not own its own character will
  always fight the replication coming in.
- **Leading the victim ahead of their replicated position on the attacker's client**, on top of
  physics, did not measurably improve what the attacker saw. It had no agreed end state to
  reconcile against, which is exactly what the recipe above provides.
- **Physics knockback simulated by the victim alone** was the baseline. It was never the problem,
  only the thing the other two tried to improve on — and the reason the attacker saw every hit a
  full round trip late.

### Reference positions

Where the push is aimed is a separate question from who simulates it, and it comes from
**reference positions**.

`PositionService` (a GlobalFunctions module, so any controller can reach it) holds that. Every
client streams its own root CFrame over `CombatService.ReportRoot` — packed as six plain numbers,
throttled to `ReportInterval` and skipped entirely below `MinDelta` studs of movement. The server
accepts a report only if every number is finite and it lands within `MaxDrift` studs of the server's
own view of that root. `PositionService.Reference(character)` then returns the reported position if
it is younger than `Staleness`, and the live root otherwise, so a withheld, stale or rejected report
degrades to exactly the old behaviour.

This matters because the server's view of both characters lags each client's by their ping, and the
attacker is mid-lunge when the hit lands. Deriving the knockback direction from stale positions aims
the push slightly wrong. The reference positions fix the aim; they do not touch the round trip.

The gate is deliberately narrow: a report can only re-aim a push inside a `MaxDrift` envelope around
where the server already knows that character is. It cannot move anyone, pick victims, change
damage, or extend reach — the `MaxReportDistance` plausibility check still runs against the real
server roots, not the reported ones.

The mover is a `LinearVelocity` in World space with `ForceLimitMode.PerAxis`, so `MaxAxesForce`
carries the per-axis meaning `BodyVelocity.MaxForce` used to and `lockToHorizontal` still leaves Y to
gravity. `LinearVelocity` is a `Constraint`, not a `BodyMover`, and needs an `Attachment`:
`PhysicsService.ImpulseAttachment` prefers the rig's own (`RootAttachment` on R6,
`RootRigAttachment` on R15) and only creates one as a fallback, keeping it rather than troving it so
two systems cannot destroy each other's. Anything testing for an active impulse should ask
`PhysicsService.GetImpulse`, **not** `FindFirstChildWhichIsA("BodyMover")`, which no longer matches.

### Facing

A hit turns the victim to look at whoever threw it. `ApplyImpulse` takes a `facing` direction and
builds an `AlignOrientation` alongside the mover, sharing the same attachment, living exactly as long
as the impulse. It is flattened to horizontal, so it is yaw only and never tips anyone over, and it
suppresses `Humanoid.AutoRotate` while it runs — otherwise the Humanoid turns the character back the
moment they have any move input.

`CombatService` passes `-direction`. The knockback direction runs attacker → victim, so negating it
looks back down the same line: the victim slides backwards while facing the attacker, which is what
the hit reactions are animated against. Per weapon and per combo, `face` turns it off and
`faceResponsiveness` controls how sharply the turn is taken — a lower number reads as a stagger, a
higher one as a snap.

`AutoRotate` is restored from an attribute rather than a captured local, and only by the last impulse
still standing. Overlapping hits would otherwise each save what the previous one left behind and
restore `false` forever.

Nothing calls `PhysicsService.ApplyImpulse` any more: knockback and the light-attack lunge are
recipes, and the **dive dash** builds its own `LinearVelocity`. It drives its falloff on
`RenderStepped` on a client and `Heartbeat` on the server, so it works on either side. It reads nothing off the controller but `.Character`, which
is why the client handler can pass a plain `{ Character = victim }` for a character it does not own
a controller for.

Damage and hit validation do not exist yet — `CombatService` is where they go.

### The attacking dummy

`Server/Services/DummyService.luau` gives any non-player model in `World.Live` a melee brain, so
stun, knockback and impulse numbers can be tuned against a victim that hits back without a second
person. It is off until asked for: set the model's `Aggressive` attribute (tick it in Explorer during
a playtest, or `aggro on` in the console), or author `combat.aggressive = true` in its NPCLibrary
entry.

The brain runs on the server and reuses the player pipeline end to end. The nearest player inside
`aggro_range` is chased with `MoveTo` (Humanoid `AutoRotate` steering); inside `attack_range` it
stops, turns onto them through an `AlignOrientation` on the root — never a CFrame write, which
replicates as a snap — and swings light attacks on `CombatConfig:ResolveAttackTiming`: same
animation, `AttackService` ease-out, weapon visuals broadcast, `HitboxService` volume and
`CombatService:ApplyKnockback` a player swing goes through. Hits chain at the player's own pace,
`max(duration, cooldown)`, through the weapon's full combo, then rest `attack_interval` after the
finisher; `ComboTimeout` resets it exactly as it resets a player. A stun or knockback on the dummy
interrupts its swing and holds it still, and its `WalkSpeed` follows `StatusLibrary` through
`StatusService:ResolveProperties`, so a stunned dummy slows exactly as a stunned player does.

**Weapons.** `combat.weapon` (or the `Weapon` attribute, swappable mid-fight) names a WeaponsLibrary
entry. The brain parents a Tool of that name into the character, so `ServerController` rigs it the
same way it rigs a player — the rigs are authored against R6 limbs, which is what the dummy is — and
`EquippedWeapon` resolves the animation set: `<Weapon>Attack<N>` per hit and `<Weapon>Idle` as its
stance between swings. Melee is unarmed, so it has no stance. A weapon missing an attack track warns
once and skips that hit rather than erroring.

Tuning lives in `Libraries/NPCLibrary/<Name>.luau` under `combat` (`weapon`, `aggro_range`,
`attack_range`, `attack_interval`, `chase`, `aggressive`). Each has a model attribute override —
`Weapon`, `AggroRange`, `AttackRange`, `AttackInterval` — read every frame, so a value can be
changed live in Explorer mid-fight. Left unset, `attack_range` is **derived from the next hit's
hitbox**: `|offset.Z| + half-depth` (radius for Sphere/Cylinder) minus `ReachMargin`, resolved per
combo index, so a wider finisher swings from further out and a per-weapon number never has to be
kept in step with the hitbox. Set it only to force a distance. It lunges with each swing
exactly as a player does — `KnockbackService.Lunge` runs on the server for a character it owns — so
the step and the shove cover the same studs and the target stays in reach through the combo.

### Finishers

The final hit of every combo (`timing.is_final`) is a finisher: instead of a knockback recipe it
**launches and ragdolls** the victim, player or NPC. `CombatConfig` gives every weapon
`DEFAULT_FINISHER` — `ragdoll` 1.5s, `getup` 0.6s, `speed` 40, `lift` 32, `spin` 540, `twist` 0.6,
`flail` 16 — and a weapon's `finisher = { ... }` overrides any key, while `finisher = false` turns
it off. `spin` is degrees per second of backward tumble on the torso assembly; `twist` adds that
share of it again as a random angular velocity so no two launches turn the same way; `flail` is
studs per second of random velocity (and a random spin) given to each loose limb, so arms and legs
leave the torso moving instead of hanging along it. The whole body still shares the launch velocity.

**Limbs must not collide while ragdolled.** The Humanoid forces limb parts non-colliding every
frame in its normal states and re-enables them on the way into `Physics` — after which an arm
hanging flush against the torso locks on contact friction and a 40 studs/s kick moves it 5°. Both
`RagdollService.enable` (server) and `RagdollService.Watch` (owner client) hold the four limbs'
`CanCollide` off every Heartbeat for as long as the ragdoll lasts; the massless colliders do the
colliding. With that, the same kick reaches the 110° cone limit.

**The colliders do collide with the body.** Each is `ColliderScale` (0.85) of its limb, so at rest
it sits clear of the torso and never starts in contact, and it carries `ColliderProperties` (low
friction) so a limb lying against the body slides rather than sticks. That is what keeps arms and
legs from sinking through the torso and head mid-tumble; there are no `NoCollisionConstraint`s
between them any more.

`CombatService:ApplyFinisher` cancels any push still running on the victim, applies `IsRagdolled`
for `ragdoll` seconds and `IsStunned` for `ragdoll + getup` (so every existing stun gate holds
through the get-up), and broadcasts `Launch(victim, velocity)` with `direction × speed + up × lift`.
A ragdoll is real physics, so only its physics owner can move it: the server launches an NPC itself
and the victim's own client applies the launch to a player (`KnockbackHandler:Launch`); everyone
else sees it through replication. A ragdolled victim ignores ordinary knockback; another finisher
re-launches them and the ragdoll time stacks.

`RagdollService` (GlobalFunctions) builds the rig once per R6 character from its own joints — no
template instances — when `ServerController` loads it: a ball socket at each shoulder and hip,
positioned from the `Motor6D` C0/C1 with limits in `Settings`, a massless collider per limb,
no-collision pairs between them, and a disabled weld from root to torso. Enabling it (the server,
reacting to the `IsRagdolled` attribute) swaps the limb motors and `RootJoint` for those and claims
the loose limbs for the character's owner, so they are simulated where the rest of the body is. The
Humanoid goes to `Physics` and back through `GettingUp` — on the server for an NPC, through
`RagdollService.Watch` on the player's own client. Shift-lock's per-frame root rotation stands down
while ragdolled.

### Trajectory debug and landing prediction

`TrajectoryService` (GlobalFunctions) does two jobs.

**Landing prediction.** `TrajectoryService.Arc(origin, velocity, size)` steps a launch under
`workspace.Gravity` every `Step` seconds and blockcasts each step with a root-sized box against
everything collidable except `World.Live` and `World.Visuals` — what the ragdoll will physically hit,
terrain and loose world parts outside `World.Map` included. The first hit becomes a landing:
`Position`, `Center` (where the root is at
contact), `Normal`, `Instance`, `Material` (by name, terrain included), `Surface` (`Floor`, `Wall` or
`Ceiling`, split at `FloorSlope`), `Slope`, `ImpactAngle` (90 is head-on), `Speed`, `Velocity` and
`Time` of flight. A finisher predicts on the server before launching, stamps `At` (the server time of
contact), sends it with `Launch`, and `TrajectoryService.Landed:Fire(victim, landing)` runs at that
moment on the server and on every client — on a client, `ObserverLag` later for anyone but its own
character, because that is when replication shows them arriving. That signal is the hook for impact visuals — craters, dust
by material, wall slams by surface — so they play on contact with no extra networking. It is a
prediction: a ragdoll tumbles, so the real body can settle slightly off the point, and the debug
label reports by how much.

**Debug ray** (client only, behind the `debug` toggle). Every knockback, lunge and launch a client
sees is drawn as **one part per character**, `workspace.@trajectory_debug.@trajectory_ray`, read like
a raycast debug line: it starts at the body's root and reaches to where the planned path puts the
body `RayLookAhead` (0.2) seconds from now. So it points the way they are heading, and its length is
their speed times the look-ahead. Knockbacks (red) and lunges (yellow) are planned with
`KnockbackService.Evaluate`, which `KnockbackService.Apply` passes in. A launch (red) is planned on
the ballistic arc from the server's launch time, pushed back `ObserverLag` for anyone but your own
character so it lines up with what replication shows.

The look-ahead is clamped to the path's end, so the ray shrinks to nothing as the body arrives. For
`DebugLifetime` after the path ends it keeps pointing at the end point: any leftover length is how
far the body finished from the plan (for a launch, the landing error). Then the ray is removed. A new
path on the same character reuses its ray. `RayLookAhead = math.huge` makes it a ray to the path's
end instead.

**Landing marker.** Where a hit lands the victim, a ball (`@trajectory_landing`, `MarkerSize`) marks
the spot. For a knockback it sits at the recipe's finish, in the knockback colour. For a launch it
sits at the predicted contact point on the surface, in `Colors.Landing`, with a stick along the
surface normal (`NormalLength`). Lunges get none. Each marker lasts until its path ends plus
`DebugLifetime`. With `DebugHud`, the landing label hangs off a launch's marker: surface, material,
slope, impact angle, speed and flight time, then `landed Δ`.

A launched body touches down within 1–2 studs of its marker, but it still carries the launch's
horizontal speed (around 40 studs/s), so it skids another 2–10 studs past it. That's momentum, not
friction: setting the limb colliders to 0.2, plastic or 1.0 friction changed the skid less than the
variation between runs. To stop a body near the marker, bleed its horizontal velocity on touchdown
from the owner's `Landed` hook.

---

## Effects

Server broadcasts a payload; every client dispatches it through
`ReplicatedFirst/Modules/ClientEffects` by dotted path:

```lua
{ Effect = "Combat.Hit", Method = "Emit", Info = { ... } }
```

`Effect` is the module's path under `Modules/Effects`, case-insensitive. Function-style modules
(`return function(Info)`) need no `Method`; method-style ones do.

**Payloads are distance-culled on arrival** — see `ClientEffects/CullingConfig.luau`, default 50
studs. This is unrelated to StreamingEnabled and much tighter. The cull measures from whichever of
`CullingConfig.OriginKeys` your `Info` carries (`Character`, `Char`, `Target`, …), so **name the key
that says where the effect renders**, or it fails open and plays everywhere.

The decision is made once, on arrival: a long-lived effect started while a viewer was out of range
does not begin playing if they walk into range.

**A payload may carry `SkipSender = true`.** `EffectService` then broadcasts with `FireExcept` rather
than `FireAll`, and the firing client is expected to have played it locally already — that is what
`AttackService:PlayLocal` does for hit effects, so an attacker sees the impact on the frame it lands
instead of after a round trip. Set it only when the sender has genuinely played it itself, or that
client sees nothing at all.

---

## The console

Konsole is vendored at `ReplicatedStorage/Utilities/Konsole` and is **not edited** — add commands
through its public API from `Server/Services/KonsoleService.luau`. Open it in game with `;` or `F2`.

```
give <weapon> [target]     spawn [npc] [weapon] [count]
clearweapons [target]      clearnpcs
debug [on|off|toggle]      aggro [on|off|toggle]
arm <weapon>
```

`spawn Dummy Sword 2` drops two sword dummies; `arm` re-equips every NPC in `World.Live` (Melee
disarms) and `aggro` flips their `Aggressive` attribute — see "The attacking dummy".

`debug` drives everything debug-gated at once — hitbox volumes, the per-swing hit report and the
status UI — through `DebugService`, which is a replicated attribute on `ReplicatedStorage`. Unset it
falls back to `RunService:IsStudio()`, so behaviour is unchanged until somebody sets it. Read it with
`controller.DebugService.IsEnabled()` and follow it with `.Changed(fn)`.

Access is a name → userId whitelist in `KonsoleService.Settings`; both must match.

`Konsole.host()` is called exactly once and merges the library's own built-ins (`clear`, `cmds`,
`ranks`, `kick`, `ban`, `kill`, `bring`, `tp`), so do not redeclare those. The library resolves its
internals with Luau string requires, which makes its directory layout load-bearing — never flatten
it.

---

## Known rough edges

Real, current, and worth knowing before you trip over them:

- **Weapon config keys are not validated** — typos fall back silently.
- **`--!strict` is on 4 of 173 authored files.**
- **`selene.toml` exists but `selene` is not in `aftman.toml`**, so lint cannot run.
- **`CharacterService` reads `Controller._IsPlayer`**, which nothing assigns — that branch is dead.
- **`Workspace.WeaponIdles`** holds roughly 40k `Pose`/`Keyframe` instances that clone into every
  playtest. It is animation authoring data with no runtime use.
