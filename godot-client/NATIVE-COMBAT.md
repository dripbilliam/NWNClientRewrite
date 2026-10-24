# Native combat/cast animation cues — partial migration

Godot now consumes the actual decoded attack and cast presentation records,
owns their animation queues/timers, selects melee/ranged/reaction clips, advances
linked attacks from original model `hit` events, and plays body/robe followers.
No attacks, damage, HP, spell effects or uses are resolved in this presentation
code. Server outcomes remain authoritative. Audio, projectiles, particles and
impact effects are still incomplete; this is not full combat acceptance.

## Native ownership

`systems/animation_queue.gd` ports the retained ClientAnimationQueue and
world-time arithmetic: stable insertion order, record identity, bounded BYTE
count, unsigned overdue durations/speed correction and signed countdown expiry.
`attack_animation.gd` ports original float32 range/direction, weapon side,
cosmetic CRT draws and ranged reaction timing. Cosmetic RNG seeding and complete
draw order, including unported sound selection, are not claimed as native parity.

`combat_animation.gd` owns native per-frame base/cue scheduling, 500 ms cast
release timing, delayed moving melee, reaction queues, hit-linked records and
model/creature lifetime retirement. Idle frames do not overwrite an active cue.
Original game state is read only. Metadata that is not disclosed is diagnosed;
the implementation does not invent a hidden class or hit-point value.

`model_rigs.gd` now dispatches authored model events from the actual primary
animation source, with original forward/reverse interval and wrap rules. Body
and robe followers share restart/loop/speed requests, but only the primary
source fires combat hit callbacks. Restarting an identical action restarts the
clip. Exported side-specific original names preserve left/right context. Original
clip transition values feed Godot blending; exact native blend/controller
arithmetic remains unaccepted. Existing GPU skins and attachment P/Q ownership
are retained. Diagnostic GPU baking runs only in explicit test probes.

`tools/combat-delivery.mjs` copies decoded events before async work, retains
canonical object lifetimes, scopes area/generation and emits read-only original
appearance/equipment metadata. Retired jobs cannot publish old attacks on reused
IDs. Actual cues trigger immediate delivery after native area admission; bounded
periodic work refreshes metadata independently of the authoritative pose stream.
The initial periodic-only check recorded 30–122 ms of extra queue age. Direct
delivery records 0 ms added backend queue age in final v3. This does not measure
total network-to-display latency.

Isolated staging **v15** exports side maps, original events, primary-source and
robe metadata. Once the native area takes presentation ownership, it disables
the hidden browser's duplicate combat-event receiver. Three's animation/render
loop stays stopped; it does not accumulate an unused combat queue. Production
main/dist remain unchanged. Original model/image payloads stay in external
temporary bundles, not authored workspace sources.

## Evidence

- `reports/combat-native-v6.json`: **4,595 checks pass**. These include 2,400
  authored inputs evaluated against the retained JS attack selector, 30 queue
  time/duration cases, 2,048 loop-category cases, 100 original event intervals
  and 13 native scheduler/lifetime checks plus four real AnimationPlayer
  lifecycle checks. They verify exact selected IDs,
  side/context, reaction changes/delay and cosmetic draw counts for those cases.
  Scheduler checks cover fixed cast duration, zero versus negative expiry,
  linked hits before clip end, moving interruption/defer/resume, no HP mutation,
  physical-model replacement, reused object IDs and callback cleanup. These are
  retained-source comparisons, not fresh native-binary observations.
- `reports/combat-node-regressions-v2.log`: **34 cases pass**: four delivery,
  eight export, nine evidence-gate and thirteen existing combat/model-event
  provider cases. Delivery tests cover captured record independence, unsigned
  IDs/age, stale jobs/actors/areas, metadata suppression and lifetime changes.
- `reports/combat-rigs-gpu-regression-v2.json`: **65 actual Vulkan GPU/rig
  checks pass**; maximum skin position error remains 0.0000169095, rigid error
  0.000000357628 against the authored original-arithmetic fixture. Earlier v1
  retained 63 passing checks but its collider-removal test was stale: it did not
  establish the area-admission scope added after the original model milestone.
  The fixture now performs real scope begin/admit and supplies transfer and
  controlled IDs. Runtime scope guards were not weakened.
- `reports/combat-world-scope-v1.json`: 17 scope checks pass.
  `reports/combat-movement-safety-v2.json`: 1,830 safety checks pass. The initial
  safety invocation omitted its ground-oracle argument, failed before a result
  and was stopped; v2 uses the proper authored oracle.
- **`reports/native-combat-local-v4.json`: all 56 actual local checks pass**
  on owned **GodotCombat**, retaining the 49 dialogue/examine/radial/spellbook/
  preparation/family checks. Actual server input contains three casts and two
  attack groups. Godot observes three casts, two attacks, two hit events and
  two reactions. All three cast samples advance original `castup` clocks and
  controlled GPU skin vertices; the attack sample plays `nwslashr` and deforms
  the controlled skin. Body and robe clocks agree. Final sample skin deltas
  are approximately 0.04417, 0.04858, 0.01659 and 0.09114 world units.
- The real combat screenshot was inspected: original equipped models appear in
  an attack pose, server combat feedback and overhead text are present, and the
  native shortcut dock/FPS HUD remain visible. Test acceptance requires actual
  incoming records and separate cast/attack GPU-deformation samples, not only
  successful request submission or an advancing clock.

The final run exits 0 and explicitly disconnects, with no native engine errors
or JS renderer errors/diagnostics. No GUI queue overflow occurs. The controlled
actor has no selector/playback failure. A real hit also exposed the expected
missing **NPC HP for an optional damage bark**; that disclosure limitation is
retained in native diagnostic history rather than replaced by guessed HP. Sound
output is not accepted. Earlier runs also observed an NPC attack of opportunity;
the final run's attack evidence does not cover every server combat-round sequence.
Linked-chain ordering remains separately authored coverage.

The first regular Prelude preview subsequently exposed inactive/finished
AnimationPlayers that the small combat fixture did not exercise. Querying their
missing current clock spammed engine errors. That failed preview is retained as
`native-combat-preview-v1.json`; the initial checkpoint is historical and
superseded. Event sampling now queries active players only, uses the terminal
boundary when a one-shot finishes, and dispatches terminal events once. Four
actual AnimationPlayer checks cover inactive, finished, repeated and terminal
event behavior. The corrected v4 combat check passes again, and
`native-combat-prelude-regression-v1.json` passes actual rendered movement/chat
and clean exit in the broader 375-mesh Prelude world without native engine or
renderer errors. It retains one existing unhandled-protocol notice for later
compatibility work. These limits are not full-scene performance acceptance.

`tools/create-combat-server.mjs` derives only from the hashed, authored
GodotGameplay fixture. It gives the passive target 2,000 HP, disables Plot and
keeps immortality. The server, not the client, decides its reactions/damage.
The module is described by `reports/combat-server-fixture-v1.json`, SHA-256
`297db9f62ac302670bd2066b8e434d880d38fe2690cb02b315b30e24a41261ad`.
Original game assets are referenced only. `join-local.ps1 -CombatSmoke -Report
<unused-name>.json` runs the owned local fixture with the existing isolated
family test character/vault and closes its own client afterward.

## Remaining work

Full native weapon/parry/impact effects, blood/gore, projectiles, spell release
effects, emitter/material/light controllers, combat one-shot/voice/footstep
audio, exact native blends and broad live ranged/multi-attack/death/shape/custom
content coverage remain open. Some undisclosed NPC metadata still prevents
particular cosmetic branches. Broader cue delivery during repeated transitions,
model replacement, latency and prolonged fights needs real acceptance.

Inventory and other player windows, full NUI, remaining startup/offline/settings
systems and every other migration-ledger requirement remain required. Tiny-room
instantaneous FPS is not sustained >=60 FPS in a complete moving captured/local
scene. The full migration/performance goal stays active. No Arelith connection
was made, unrelated games are preserved, and the regular server is restored to
Prelude after this milestone.
