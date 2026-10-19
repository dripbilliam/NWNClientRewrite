# Move-away actions and data-selected control scripts

Follow-up: [on-hit/status delivery](on-hit-status-delivery.md) resolves the broader
Fear test failure described below. Original code reproduces both tile query
limits; they remain blocked queries with detailed warnings. On-hit Slow, linked
delivery and damage charm/sleep cleanup now allow the broader scenario to pass.
The earlier failure captures below remain historical evidence.

Single-player is the current acceptance priority. This increment completes a
bounded movement/control path; full spellcasting, combat and campaign acceptance
remain open. The persistent goal stays active.

Read-only target: NWN:EE89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project changes were made.

## Original owners and implementation

| Owner | Address | Observed behavior |
| --- | --- | --- |
| MoveAwayFromObject command | `1405363d0` | Creature, nonzero commandability, valid target; queue action3 with last-group selector FFFE, run/distance and ten retries. |
| MoveAwayFromLocation command | `14050e400` | Exact commandability1, existing same area, inclusive 3D radius; compute destination, add ordinary movement and action44. |
| Object/location action execution | `1403b3180` / `1403b27f0` | Dead/dying/exhausted gates, object duplicate-group cancellation, strict `(distance-.01)` radius, retry/front insertion, shared movement and pathfinding wait. |
| ComputeAwayVector | `140369a40` | Eight rotated candidates, native float operations/trigonometry, collision checks, bounded fractional fallback, directional scoring and later-wins ties. |
| Normalize/magnitude | `140230920` / `1402303d0` | Execute original arithmetic in the oracle, including coincident and signed-zero inputs. |
| Creature ClearAction | `1403870b0` | Actions3/44 use the shared movement cleanup tail, preserving native lock and stamp rules. |
| EffectTurned constructor | `1405180b0`, ordinal379 branch | Native effect8, subtype8, duration-type0, integer kind4. |
| Heartbeat/control script | `1403a4410`, lookup blocks `1403a4643..1403a4709` and `1403a4717..1403a47db` | Active timer captured before spawn; physical StateScripts row selected by state BYTE, or associate row7. SCRIPTNAME is read and run for canonical self, followed by native commandability reset. |
| StateScripts loading | `1402b75d8..1402b7677` | Resource is StateScripts; rules table stored at +278, freed/null on failed loading. |
| Faction leader / script wrapper | `1404ae310` / `140524190` | Private faction prefers a PC/familiar. NPC faction uses highest strictly positive raw CR; first tie wins. Script wrapper repeats GetFaction after its null guard. |
| GetChallengeRating command | `140520cd0` | Return raw float stats field D0 for a creature with stats; zero otherwise. |

REA dossiers are retained under `backups/animations/rea-move-away-*.json`,
`rea-creature-control-heartbeat-owner.json`, `rea-faction-leader-*.json` and
`rea-challenge-rating-command-owner.json`. Call order, output bits, stack error
gates and cleanup are validated with original-instruction oracles, rather than
pseudocode alone.

`src/move_away.js` supplies the reusable vector/command/action owners.
`CombatRuntime` connects them to canonical registry objects and actual geometry,
movement and queue helpers. `ModuleSession` binds both move-away commands,
EffectTurned, GetFactionLeader and GetChallengeRating. No spell name, faction
member list, destination or campaign outcome is prescribed by the runtime.

One integration defect was shared storage: native offsets54c/550 were represented
by separate heartbeat and effect-controller fields. They now alias one pair of
cells; contradictory imported values fail explicitly. A control effect's native
day0/time1 reset consequently reaches the real heartbeat. Its active clock also
replaces the incorrect world-only selection during pause exclusions.

The duplicate cancellation loop has an explicit no-progress failure if its
matching queued action survives cancellation. This is a diagnosed recovery
boundary, not a claim of reproducing an original infinite loop.

## Validation and limits

- `inspect-native-away-vector.py`: 426 original-code cases. Exact output float
  bits and every TestDirectLine argument/order match the implementation.
- `inspect-native-move-away.py`: 904 original-code cases across commands,
  actions, Turned construction, movement cleanup and bounded StateScripts lookup.
- `inspect-native-faction-leader.py`: 632 original-code cases, including raw
  PC/familiar flags, CR ties/zero/negative/fractions, missing members/stats and
  VM error paths. Lower allocation/VM/geometry boundaries are captured, not
  whole-engine execution.
- Full Node suite: **1962/1962 pass**, `move-away-full-v1.txt`. Build passes,
  `move-away-build-v1.txt`, with the existing bundle-size warning.
- Electron regression: `move-away-ui-v1.txt` passes spellbook selection,
  right-click self casting, prepared-slot consumption, F2 targeting/cancellation,
  cast animations and counterspell mode22. A shutdown GPU message is retained.
- Installed Prelude probe `installed-move-away-v10.json`: five checks pass.
  Both command forms move a hostile authored goblin from2m to5m distance using
  real native area geometry and movement states. Real frightened/turned effects
  select the installed StateScripts row and execute untouched `NW_G0_fear` NCS;
  distance exceeds16m, and natural expiry clears control state/icons and restores
  commandability. Canonical preexisting object references remain identical.

The installed probe runs selected native frames. Startup and general AI scheduling
are disabled; spawn state is explicitly initialized. Direct movement fixtures
isolate heartbeat, while effect fixtures retain real heartbeat/control/perception
and scheduler callbacks. Those callbacks allocate32 authored creatures/items;
the probe reports additions and verifies preexisting identities, rather than
incorrectly requiring an unchanged allocation cursor. Missing `plc_w02.pwk` and
other initialization diagnostics remain in the load journal. Runtime trap and
speech-presentation warnings remain recorded. This is not full Turn Undead feat
admission, spell acquisition, renderer movement sampling or campaign acceptance.

Early failed fixtures are retained: v1/v2 omitted AI frame elapsed time;
v3/v4 selected a neutral dead-goblin template whose script correctly found no
enemy to flee; v5 incorrectly prohibited legitimate callback allocations.
v6, v8 and the final default v10 pass the bounded integration.

## New single-player failures requiring follow-up

The broader optional `--fear-cast` experiment is retained in the probe. Its first
run, `installed-move-away-v7.json`, failed during ordinary cast/combat processing;
the final source reproduces both failures with explicit `--fear-cast` in v9:

1. Tile `tic01_f14_01` hit the diagnostic `Native tile triangle walk exceeded
   512 iterations` from actual move-away geometry queries.
2. A real strike from the cleric reached unimplemented native on-hit property48
   on item568, aborting damage resolution.

These are unresolved failures, not accepted behavior. The optional experiment
must be rerun with `--fear-cast` and cannot be counted as a passing Fear spell
cast. Native on-hit handlers and tile traversal are next single-player work;
do not replace them with skipped damage or synthetic destinations. Keep the
strict failure reports while investigating original owners.

Active spell audit v53 reports54 unbound commands and22 missing impact scripts
(840 spell rows,618 named scripts,596 loaded). Its exit1 is expected from the
recorded missing resources, not a passing ecosystem check. Binding presence alone
does not prove branch completion. Single-player campaign testing, save/reload,
all spell/combat branches and full pause presentation remain open.

Verified checkpoint `backups/move-away-controls-1962-20261017-v2.zip` contains
10581 files /145268835 bytes; every archived length and SHA256 was verified.
`move-away-checkpoint-v2.txt`, session75988 terminal0. This verification note
was added after sealing. The earlier v1 archive is invalid (22 bytes): invoking
PowerShell5.1 lacked SHA256.HashData; its failure log is retained, and v2 ran
under the workspace's PowerShell7. No backup claim is made for v1.
