# Native parry sparks — scoped mode0 migration

The direct native entry connects the existing original-derived melee parry
callback to a native location effect. This does not complete weapon/shield
presentation, combat, or the full base-game goal.

## Original behavior and implementation

Read-only target: nwmain.exe SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
SpawnHitVisuals14080bb10 mode0 looks up the attacker's current facing target,
reads that creature's active appearance.CREPERSPACE, queries the attacker's
animated impact point, and creates type11 area visual118 at a calculated point.
It does not substitute the attack-record target or attach sparks to either
fighter. Space at or below0.5 is doubled. Z uses source ground Z plus the
absolute impact-height difference from the target. Height above5 warns but
does not suppress the effect. All operations preserve original float grouping.

| Source | Responsibility |
| --- | --- |
| systems/native_data/parry_visual.gd | Complete bounded original mode0 placement branch with explicit lower providers |
| systems/native_render/parry_world.gd | Real combat signal, displayed pose/facing, active table read, stale lifetime/model checks |
| systems/native_render/effect_world.gd | Shared native create_area_visual path for local sparks and received server area effects |
| systems/area_visual_runtime.gd | Existing original area impact/retirement clocks, model/audio requests and cleanup |
| tools/native-parry-fixture.mjs | Authored localhost encounter; original server creates/equips the NPC weapon and decides every attack result |

Only the existing hit branch for received result2/4, the required defender
parry animation, non-unarmed weapon and defender equipment invokes this path.
Combat event diagnostics now include the received record. That diagnostic target
does not change facing-target placement. Resource names come from the active
visualeffects row118 through the existing native area loader.

Pending requests preserve their hit-time displayed source/target positions,
impact point and facing. They reject replaced canonical actors, facing targets
or physical source models. Once created, the spark has an independent private
type11 owner and survives source removal until its own original timer retires it.
It never enters canonical interaction/targeting identity. World close disconnects
the hit callback, discards pending requests and retires all remaining effects.
Queue/capacity limits and asynchronous publication are adapter policies; full
original loading/paused-clock/event order remain separate acceptance.

## Repeated physical event investigation

The first live run showed multiple sparks at identical hit times. Independent
original resource reading found literal repeated hit/blur/footstep entries in
the active pmh0 → a_ba supermodel chain, including two hits in1hslashr and three
in1hslashl/1hcloseh. Metadata/hash capture is
reports/native-parry-source-events-v1.json. Native parser and inherited worker
metadata match those physical arrays.

Read-only REA observed AnimateEvents14004fce0..14004fe88 iterate every matching
physical entry, with no event-name deduplication. The retained receipt is
reports/native-parry-animate-events-research-v1.json. The unchanged original
instructions were executed for24 intervals from the independently read events;
reports/native-parry-original-repeated-events-v1.json preserves their calls.
The native event owner matches them. No blanket deduplication was added.

This proves the lower original dispatch behavior, not the complete upper combat
Hit listener/action mutation or original-client effect counts during that same
fight. Paired-client acceptance remains required. The primary body currently
uses its supported native Godot AnimationPlayer path for inherited clips whose
full original controller reconstruction is still unavailable; no JS presentation
or asset preparation participates.

## Acceptance evidence

- native-parry-data-v1: 54 checks, including52 complete original mode0 executions
  with captured object/table/impact/area boundaries. No real scene in this test.
- native-parry-world-final-v1: 21 actual original-model checks: combat signal,
  deliberately different attack-record target, physical impact, private area
  model/clip/placement, source-independent lifetime, retirement, source/target
  reuse, physical model replacement and world closure. Its no-geometry collision
  callback is explicit component scope; real scene collision is separate.
- native-parry-event-records-v1: 49 checks: independent resource identities,
  native parser/inherited worker metadata and24 original event-function cases.
- native-parry-combat-regression-v1: 15 cue delivery, ordering, replacement and
  cleanup checks; this is authored component scope rather than real combat.
- native-parry-final-v1: 15 actual localhost original-server checks. The original
  fighter sample attacks an equipped authored NPC. Genuine result2/4 and the
  native hit callback create row118 particles; the selected spark changes1,989
  viewport pixels, remains outside server identities and retires its actual
  model. Native debugger, source pins and worker cleanup pass.
- native-parry-casting-regression-v1: 39 actual original-server effect/area,
  Fireball/Magic Missile, Detonate and cleanup checks after sharing area creation.

The earlier native-parry-live-v1/v2/v3 failures are retained. Neither a
template-only nor an embedded load-time NPC weapon yielded the required equipped
target. The final fixture provides martial proficiency and uses ordinary original
CreateItemOnObject/ActionEquipItem/ActionAttack script actions. Both changes were
made together; the failures do not independently prove which loading/proficiency
condition caused the earlier absence. No replacement-client equipment state or
parry animation/result is forced. Live v4/v5 and the final fixture pass.

Current-source regressions also pass: native-parry-gameplay-regression-v1 has65
real server inventory/equipment/spell/quickbar/store/level/rest/feat/combat checks;
native-parry-bow-regression-v1 has24 real flight/blood/ammunition/expiry checks;
native-parry-prelude-regression-v1 passes two rendered campaign cycles, one
streaming abort and pending-connect cancel/reconnect. Final live runs exit0 with
unchanged sources, debugger traps armed, no caught exception and zero remaining
workers. Particles and testing preferences use isolated files.

Aggregate read-only audit: tools/audit-native-parry.mjs writes
reports/native-parry-final-audit-v1.json. It verifies relevant current source
pins, original placement/resource/event corpus identities, real server outcomes,
pixel evidence and the verified source archive. Before:
backups/native-blood-visuals-direct-after-v1.zip,
SHA17fc2fbdf5f21891d9bd0408a35a39b7751651b4936ee2ed88ce1cac41d08234.
After: backups/native-parry-visuals-direct-after-v1.zip; its read-back manifest
contains the archive/per-file hashes. Original art/binaries remain external.

The next weapon-effect boundary referenced by the original Hit callback is
FUN1407fd6b0. Caller receipt/pseudocode are retained in
reports/native-parry-hit-callback-research-v1.json; the callee's behavior is not
established by that call alone and has not been declared implemented.

Particles still default off per user preference; the isolated tests explicitly
enable them and restore the setting. Existing scene-wind diagnostics for unrelated
emitters and black terrain wedges remain visible. Shield block attachment,
weapon trails/special effects, full reaction/death/audio and clock/shape behavior,
broader custom resources and paired-client gameplay remain open. No automated
public/Arelith connection was made. Background captures are not FPS acceptance.
