# Live damage runtime checkpoint — 2026-10-12

Updated status: [Combat action-loop checkpoint](combat-action-loop.md). Native damage party-state/initiative broadcasts and default attack/damage event delivery are now connected; the earlier open-work statements below are historical.

Scripted damage now reaches canonical live HP, mitigation budgets, damage
history, direct OnDamaged/OnDeath scripts and queued player lifecycle events.
This is a partial local-authority adapter. Ordinary attack actions are not yet
playable, casting is not implemented, and native/server parity is unverified.

Target: NWN:EE `89.8193.37-17`, x64 `nwmain.exe`, SHA256
`3B7CB1252E0EDB2CE22D7971F333AADE027039AE30A45B4BC64732C3E6BEC73A`.
The installed binary, game assets and open Ghidra project were not modified.
This extends [damage providers](combat-damage.md).

The subsequent [damage-effect checkpoint](combat-damage-bonuses.md) adds
active-table equipment/damage bonus queries and partial base skill queries.
Validation below describes this earlier 255-test checkpoint.

## Native evidence and connected behavior

Full hash-checked assembly is retained under `backups/animations/` in
`live-damage-hp-death-asm.txt`, `live-damage-constructor-difficulty-asm.txt`,
`live-damage-query-event-asm.txt`, `live-damage-shield-status-asm.txt`,
`live-damage-appearance-removal-asm.txt`, `live-damage-command-table-asm.txt`
and `live-damage-module-lifecycle-asm.txt`. OnApplyDamage's full-range copy
export from the prior checkpoint remains controlling evidence. Bridge exports
are supplementary; returning cleanup calls can truncate their pseudocode.

| Native function / call site | Connected behavior |
| --- | --- |
| OnApplyDamage `0x140428740` | Script effect 38 consumes its native 39-integer layout. Unprocessed damage runs immunity, resistance and reduction before HP subtraction; processed damage does not repeat mitigation. Present creature history components each receive the mitigated total, while HP loses that total once. Plot targets preserve their separate zero-damage path. |
| DoDamage `0x14038a930`; HP getter `0x140495130` | One live int32 base/temp source in `object.stats`, short-valued getters and total-HP UI. Temporary effects are consumed and immediately removed with live-list restart. The async adapter shares the synchronous primitive's algorithm. Refreshing stats preserves HP and object identity; authored GFF remains unchanged. |
| Temporary HP apply `0x1404346c0`; removal `0x140438d60`; RemoveEffectById `0x140498280` | Removal hook runs while the uint64 handle is still live. Removing temporary HP can run death scripts before the outer damage continues. Nested removal requeries the handle before deleting it. |
| LoadDifficultyInfo `0x1402a7d50`; SetDifficulty `0x1402cd8c0` | Active `diffsettings` physical rows and columns, native integer conversion and byte storage. Session difficulty is explicit and clamped to 0..4; the local default is Normal. Damage consumes option 5 through this provider. |
| Resistance/reduction constructors `0x1405195c0` / `0x140519410`; apply `0x14042a420` / `0x14042a380` | Native integer normalization, live sorted types 2/12, capacity edits and immediate budget depletion/removal. Feedback is a local typed event; linked icons and native packet routing remain diagnosed. |
| Heal `0x14042df10` | Healing updates base HP, not total HP. Recovery, negative-level cleanup and surrounding feedback/encumbrance providers remain incomplete and diagnosed. |
| Initiative `0x14039f100` | Pending==1 gate, d20 before ability/feat modifiers, native feat precedence/rule keys and signed-byte storage. Damage rolls defender initiative before attacker initiative. |
| CheckActionLength `0x140375430`; UpdateAppearanceDependantInfo `0x1403a69f0`, assignments `0x1403a6c14..0x1403a6c68` | Damage reaction pauses/checks round state and selects the native animation number with branch-dependent RNG. Selection reads active appearance `MODELTYPE`, not the mesh resource name. Playback and pause scheduling remain unconnected and diagnosed. |
| LastDamager `0x140529fc0`; LastKiller `0x14052a440`; last damage `0x140495690`, `0x140521a60`, `0x1405315e0` | Canonical creator/killer references and native damage-history queries. Invalid combined flags return zero; absent stored components preserve -1. History is committed before direct creature OnDamaged. |
| GetMaster `0x14052b610` | Reads the creature's stored canonical master ID without resolving it, including zero, external and stale references. Non-creatures return invalid. Inconsistent non-invalid master / associate type zero is recorded as the native handler warns. Associate creation and ownership mutation remain pending. |
| SetLastHostileActor `0x14049b070`; query `0x14052a2e0` | Live alive/non-dying checks, plot invalidation, AoE creator resolution and query-time stale reference clearing. Missing AoE ownership and same-faction area PVP providers remain diagnosed. |
| OnApplyDeath `0x14042aa40` | Partial creature lifecycle: action cancellation, killer assignment, direct OnDeath before death flag/effect purge, native HP threshold handling, live immediate purge/restart and queued player death. Canonical dead objects remain registered. Door/placeable damage scripts and death scripts are queued; destroyed-door state reaches existing door presentation. |
| InitializeCommands `0x14054de30..0x1405520ce`; ExecuteCommandModuleAccess `0x140536240`; Module::EventHandler `0x14047c0b0` | Engine 291 reads module +0x388 (last player died); 410 reads +0x38c (last player dying), regardless of caller self. Event 10 writes +0x388; 32 writes +0x38c before its script, including empty scripts. Entering (+0x344) is separate. The earlier alias inference from partial command-table references was rejected by the full table and handler audit. |

The scheduler awaits effect expiry and its direct lifecycle scripts before
dispatching queued events. While a script awaits resource I/O, movement,
actions and simulation time do not interleave another frame's world mutation.
Rendering continues. These internal events are not invented native packets.
Authoritative multiplayer updates will require their own mapped adapter.

## Validation

- All **255 tests** and the production build pass. New coverage exercises
  mitigation/removal order, nested script healing, multicomponent history,
  temporary HP removal/death reentrancy, expiry serialization, player module
  event histories, initiative/reaction RNG, plot/difficulty/immortal gates,
  wide effect handles and zero/external object IDs.
- A real owned NCS fixture executes through the VM, reads damage history and
  last damager, and heals before damage feedback. This checks integration,
  not an independent original-game outcome.
- `scripts/smoke-damage.mjs` passes against Prelude and Witch's Wake with
  startup scripts disabled and the same generic actor-selection code. In
  each, the installed BIC starts at base HP 5, gets temporary HP 5, then takes
  damage 7, leaving base HP 3 and temporary HP 0. Three placed actors take
  damage 3. Lethal damage preserves the actor's canonical ID and records its
  killer; base HP remains the native deep negative result.
- The native GetMaster getter is now connected. Authored scripts proceed to
  **ActionEquipMostDamagingRanged** in `nw_c2_default6` in both modules and
  still fail at **GetSkillRank** in `nw_c2_default7` in Witch's Wake. Failures
  remain recorded; these scripts have not been claimed to complete.
- Hidden bundled full-area/character UI verification passes with an upright
  PC head. Existing bitmap, walkmesh and model-controller omissions remain
  diagnosed. This did not schedule an attack or cast.
- Reports: `live-damage-all-tests.txt`, `live-damage-build.txt`,
  `live-damage-{prelude,witchswake}.json`, `live-damage-renderer.txt` and
  `live-damage-character.png`, under `backups/animations/`.
- A periodic pre-edit source backup is
  `backups/combat-live-before-20261012-152216.zip`; the completed checkpoint
  is archived separately under `backups/combat-live-checkpoint-*.zip`.

There is no independent native encounter oracle and no original/replacement
client pair tested on a server. Passing these checks does not establish combat
parity.

## Remaining required work

Damage during casting (animation states 15/16), status effects (type 8), or
damage shields (type 61) is explicitly rejected and diagnosed before HP or RNG
mutation. Concentration, sleep/charm cleanup and shield recursion need their
native providers. Missing appearance MODELTYPE also records an omission.

GetTotalEffectBonus damage branches, broader item-effect projection, equipment
mutation and full immunity initialization remain incomplete. Native death XP,
witness reputation, associate cleanup, encounter counts, corpse/body bags,
linked-door destruction, object cleanup, reaction/dying/death animations and
native GUI/feedback messages remain incomplete and diagnosed.

Next, finish those providers and ordinary attack approach/target/perception,
round scheduling, cancellation and presentation; validate an actual melee
encounter against independent native outcomes. Then connect spell requests,
slots, DCs, metamagic, interruption and impact scripts through the same state.
The [compatibility contract](combat-compatibility-contract.md) still applies.
