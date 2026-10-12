# Rune Spellcasting System

An original Luau gameplay system from **Haunt & Shriek**. Players collect physical runes, combine them into a spell, and cast abilities that reveal nearby hazards, change movement, place traps, or affect other participants.

**Five rune types · 15 ability definitions · 36 original ModuleScript exports**

This is a source portfolio extraction from the currently open match place, not a standalone Roblox package. The scripts retain their original logic, comments, naming, whitespace, and game dependencies. No replacement implementations or bootstrap scripts are included.

## Start reading here

| Entry point | What it shows |
| --- | --- |
| [Shared rune definitions and matcher](ReplicatedStorage/Modules/Data/Runes.luau) | Rune data, combination-to-ability mapping, and `GetAbilityFromRunes` |
| [Server ability dispatcher](ServerScriptService/Server/PlayerActions/Ability/init.luau) | Reading owned rune tools, validating targeting data, consuming runes, and calling the selected handler |
| [Client selection and targeting](StarterPlayer/StarterPlayerScripts/Client/Keybinds/Ability.luau) | Tracking rune selections and selecting an interactable or floor position |
| [ItFollows handler](ServerScriptService/Server/PlayerActions/Ability/ItFollows.luau) | Server-side enemy selection, pursuing wisps, retargeting, and lifecycle cleanup |

The shared rune module contains **112 non-comment, non-blank lines**; the server dispatcher contains **65**. Counts exclude full-line and inline comments, long comments, and blank lines.

## Core features

- Rune models carry a `Type` attribute and the `Rune` collection tag. Collected models are held inside backpack tools.
- A shared definition table maps five single-rune spells and ten distinct two-rune combinations to named handlers.
- The client tracks rune additions through the `RuneHUD` local bind, previews targeting, and requests a cast. The server independently derives the spell from the player's backpack.
- Missing interactable or floor targeting data rejects a cast before rune consumption. `ItFollows` also performs server-only preparation to select a valid enemy before consuming runes.
- Spell handlers support direct client abilities, traps on interactables or floor positions, a protective ward, an AI decoy, and a pursuing wisp.
- Client modules implement camera changes, particle effects, highlights, animations, sound, and character movement.

## Technical implementation

### Selection and combination recognition

Rune selections are arrays of rune-name strings. On pickup, the client invokes the `Item` bridge with the rune model and `Action = "PickUp"`. After successful replication into a tool, the pickup module fires `RuneHUD`; the targeting module appends the tool's rune type to `currentRunes` and recalculates the ability type. Its tracked tool-destruction connection clears that local selection after consumption.

The original game's general `Items` handler checks whether adding a candidate rune produces a known combination. It also checks item ownership and pickup distance before granting the tool and updating `RuneCount`. That mixed-purpose handler and the general `ItemClass` helper are inspected dependencies, rather than exported copies of unrelated orb gameplay.

`Runes.GetAbilityFromRunes` iterates `AbilitiesByRunes`, first requiring the same number of selected and required runes, then using `table.find` for each required name. Matching is independent of selection order for the defined combinations. It returns the ability name or `nil`. The table contains no three-rune spells; the commented-out `PERTHRO` definition is inactive.

Each ability record contains `NeededRunes`, a description, and optional targeting and shop metadata. `SPprice` and `DevProdID` are retained original configuration, not purchase processing performed by this cast path.

### Targeting and execution

The client casts a camera-center ray up to 15 studs. `Interactables` resolves an `Openable`-tagged model; `Cursor` returns a hit position only when the surface normal's Y component is at least `0.65`. Untargeted abilities do not use these target functions. The original parent keybind router sends the request through the `PlayerAction` bridge, using Q on desktop or the mobile ability button.

`Ability.PerformAction` scans the server-side backpack, reads the `Type` of each `Rune`-tagged tool model, and calls the shared matcher. The returned name selects a child module registered in `RuneAbilityModules`. The dispatcher checks interactable model/tag or floor-position type, runs an optional `CanCast`, then destroys the collected rune tools, resets `RuneCount`, plays the cast sound, and calls `CastAbility`.

The client ray distance and floor-angle checks are client-side checks; the exported dispatcher does not repeat those spatial checks on the server. Rune consumption occurs before `CastAbility`, with no rollback here if a handler later fails. These behaviors are preserved from the original implementation.

## System architecture

```text
Rune spawn/grant
  → proximity prompt → Item bridge → original Items / ItemClass
  → backpack rune tools → RuneHUD → client selection and targeting
  → Q / mobile button → PlayerAction bridge → original PlayerActions router
  → server Ability.PerformAction → shared combination matcher
  → pre-cast checks → consume tools → named CastAbility handler
  → Ability / VFX / Trap bridges → client movement, presentation, and traps
```

The outer action router supplies match/alive-player gating and distributes returned VFX data. The client `Abilities` module listens to the `Ability` bridge and dispatches received names to its children. The original general `VFX` router calls the corresponding effect module's `Play` or `Stop` method. `Traps` registers model or position traps, checks nearby participants for point traps, applies ward checks, and invokes callbacks or effects. `WardService` stores and consumes the ward state on participants.

### Exported modules

Paths mirror the original Roblox service hierarchy. Every exported source is a **ModuleScript**. Where a source module owns exported source children, `init.luau` represents that parent module; its siblings represent the children. Folders used only as containers remain folders. [source-manifest.json](source-manifest.json) records the exact Studio path, class, byte length, and SHA-256 for every source file.

| Original location | Exported components | Responsibility |
| --- | --- | --- |
| `ReplicatedStorage.Modules.Data` | `Runes` | Rune visuals, weighted random selection, spell definitions, and shared matching/accessors |
| `ServerScriptService.Server.Match.LoadMap.ItemSpawning` | `Rune` | Template cloning, rune appearance, spawn tagging, and explicit starter-rune grants |
| `ServerScriptService.Server.PlayerActions.Ability` | Parent dispatcher and all 15 spell handlers | Server spell selection and execution |
| `ServerScriptService.Server` | `Traps`, `WardService` | Trap activation, participant handling, and ward consumption |
| `StarterPlayer.StarterPlayerScripts.Client.DetectCollectionInstances` | `Runes` | Pickup request, replication wait, local rune event, feedback |
| `StarterPlayer.StarterPlayerScripts.Client.Keybinds` | `Ability` | Local rune tracking, camera-center raycast, and target highlighting |
| `StarterPlayer.StarterPlayerScripts.Client.Abilities` | Parent dispatcher, `Hopscotch`, `Tempest`, `RevealTraps`, `SeeNearbyRunes` | Server-requested client movement and reveals |
| `StarterPlayer.StarterPlayerScripts.Client.VFX.Abilities` | `Hopscotch`, `FrightPocket`, `Flashbang`, `GloomShroud`, `BlackHole`, `FrightTrap`, `TellBells`, `CalamityWard`, `ItFollows` | Spell presentation, camera behavior, sound, and cleanup |

### Defined spells

Every ability below has a corresponding exported server handler. Target kinds describe the original definition table; an em dash means no client-picked target.

| Runes | Handler | Target kind | Implemented behavior |
| --- | --- | --- | --- |
| BERKANA | `PerilSight` | — | Sends nearby trap positions to client `RevealTraps` |
| DAGAZ | `RunicSight` | — | Sends nearby rune models to client `SeeNearbyRunes` |
| OTHALA | `Hopscotch` | — | Requests the client dash and broadcasts its effect |
| ALGIZ | `FrightPocket` | Interactables | Registers an interactable jumpscare trap |
| JERA | `FrightTrap` | Cursor | Registers a floor trap with skeleton animation |
| BERKANA + ALGIZ | `Flashbang` | Interactables | Registers an interactable flash effect trap |
| BERKANA + JERA | `Tempest` | Interactables | Registers a knockback trap |
| ALGIZ + DAGAZ | `Doppelganger` | — | Spawns a moving decoy with explosion/knockback behavior |
| JERA + DAGAZ | `GloomShroud` | — | Applies a darkness effect to another player unless warded |
| BERKANA + DAGAZ | `HauntingDecoy` | Interactables | Registers an approach-triggered callback that toggles the selected object |
| JERA + ALGIZ | `StaticCharge` | Interactables | Registers a lightning-effect trap |
| BERKANA + OTHALA | `BlackHole` | Cursor | Registers a floor trap that invokes realm exile |
| OTHALA + DAGAZ | `TellBells` | Interactables | Registers a trap that attaches movement-responsive chime audio |
| OTHALA + ALGIZ | `CalamityWard` | — | Grants a ward consumed by supported spell checks |
| JERA + OTHALA | `ItFollows` | Curse | Selects an enemy and spawns a pursuing wisp that reuses `BlackHole.Exile` on contact |

## Code highlights

- **One shared mapping for client and server:** [`GetAbilityFromRunes`](ReplicatedStorage/Modules/Data/Runes.luau) drives local targeting and server dispatch from the same definitions.
- **Pre-cast preparation:** [`PerformAction`](ServerScriptService/Server/PlayerActions/Ability/init.luau) supports a handler's optional `CanCast` hook. [`ItFollows.CanCast`](ServerScriptService/Server/PlayerActions/Ability/ItFollows.luau) checks its template, caster, and enemy availability, returning prepared target data before runes are destroyed.
- **Character-volume dash casting:** [client `Hopscotch`](StarterPlayer/StarterPlayerScripts/Client/Abilities/Hopscotch.luau) computes a cast box from the R6 head and torso, blockcasts the dash path, uses `LinearVelocity`, and restores collision groups, camera state, and connections on completion.
- **Wisp lifecycle management:** [server `ItFollows`](ServerScriptService/Server/PlayerActions/Ability/ItFollows.luau) uses Heartbeat movement, retargets unavailable enemies, counts overlapping immobilizations, and cleans up on completion or match stop. [Its client effect](StarterPlayer/StarterPlayerScripts/Client/VFX/Abilities/ItFollows.luau) uses reveal IDs to avoid stopping a newer camera reveal with an older message.
- **Trap and ward coordination:** [`Traps.AddTrap` / `Traps.Check`](ServerScriptService/Server/Traps.luau) and [`WardService.TryConsume`](ServerScriptService/Server/WardService.luau) share participant checks across relevant effects.

## Technologies

Roblox Studio and Luau, with Roblox APIs including `CollectionService`, `RunService`, `TweenService`, `ContentProvider`, and `Players`; workspace raycasts/blockcasts; attributes and tags; `ProximityPrompt`; `LinearVelocity`; camera controls; highlights; particles; animation; and sound. Network calls use the game's **BridgeNet2** dependency, while local events use **SameSideBinder**.

## Excluded dependencies and assets

The extraction deliberately keeps general game infrastructure and non-source instances outside this repository. It cannot run by copying the `.luau` files into an empty place.

| Dependency boundary | Required original components |
| --- | --- |
| Shared libraries and data | `ReplicatedStorage.Modules.Library.BridgeNet2`, `SameSideBinder`, `Janitor`; `Modules.Shared.Types`, `SoundModule`; `Modules.Data.Points` |
| Pickup and initialization | `Server.Items`, `ServerScriptService.Modules.Classes.ItemClass`, original startup/load-map modules and collection detector; `workspace.Items` and the map's spawn locations |
| Action, UI, and effect routing | Parent `Server.PlayerActions`, client `Keybinds`, client `VFX`, client `UserInterface.MainHud`; the `RuneHUD` event producers, including starter-rune HUD handling; client `Traps`; `GeneralVFX.SetupTrap`, `Explosion`, `Lightning` |
| Other game services | `Server.ParticipantService`, `PointsService`, openable-object bind handlers and callers of `Traps.Check`; `ServerScriptService.Modules.AIMovement`, `RealmTrap`; client `Modules.ControlLock`, `PopUpModule`; match state, participant attributes, pedestals, and character/collision setup |
| Audio and UI content | The original `SoundModule` sound bank, cast/pickup sounds, ability button and HUD assets |

Required child templates remain in the original place. Their names are listed below so the source dependencies can be reconstructed without inventing replacement assets:

| Exported module | Non-source children omitted |
| --- | --- |
| Server rune spawner | `Rune` model |
| Server `Doppelganger` / `ItFollows` | `DoppelgangerTemplate` model / `WispTemplate` part |
| Client `RevealTraps` | `RedAura` attachment |
| VFX `Hopscotch` / `FrightPocket` | `DashPart` / `BatPart` |
| VFX `Flashbang` | `FlashbangGui`, `FlashbangPart` |
| VFX `GloomShroud` / `BlackHole` | `Darkness` atmosphere / `Vortex` attachment |
| VFX `FrightTrap` | `Skeleton` model, `Animation` |
| VFX `TellBells` / `CalamityWard` | `TellBellsChime` sound / `Ward` particle emitter |

The shared rune module's `PackageLink` is also omitted. The source retains original asset and developer-product IDs referenced by the implementation; no credentials or private access tokens were found in the exported source.

## Demonstration

**Gameplay video: pending — add a recording here.**

To demonstrate the actual system, use the original experience or a separate copy containing its full dependencies:

1. Start a normal match with at least two eligible participants. The broader game's startup and match state must be active; some abilities require another player or participant.
2. Collect OTHALA and press Q, or use the mobile ability button, to show a single-rune `Hopscotch` cast.
3. Collect BERKANA + ALGIZ, aim at an `Openable` object within the client raycast range, and cast `Flashbang`. Have another participant trigger it.
4. Try a targeted cast while aiming into empty space to show rejection without rune consumption, then aim at a valid target and cast.
5. Collect JERA + OTHALA and cast `ItFollows` with a valid enemy present to show server target selection and the pursuing wisp.

For reconstruction in a separate place, create ModuleScripts at the manifest paths, put each `init.luau` source on its named parent module, restore the documented libraries/routers/templates and map instances, and retain the original tags, attributes, character setup, and collision groups. No automated runtime test or play session was performed during extraction, to keep the open Studio experience unchanged.

## Source provenance

Sources were read from the open **Haunt & Shriek [MATCH]** Studio instance, place ID `137133797633202`, universe ID `10026467440`. Each export was checked against its original source byte length and checksum. The manifest provides SHA-256 hashes for subsequent file comparison. Documentation is separate from the unchanged Luau files.

## Author

**Ara5h** · Roblox **@ItsAra5h** · GitHub **[Ara5hhh](https://github.com/Ara5hhh)**
