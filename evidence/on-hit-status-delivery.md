# On-hit dispatch, linked delivery and damage status cleanup

This is progress toward single-player spell/combat acceptance. The previous
turn completed native move-away/control integration and preserved the broader
Fear casting failure. This increment follows that failure through actual
geometry, weapon properties, delayed effect delivery and damage callbacks.
Full spells, combat and campaign acceptance remain incomplete; goal ACTIVE.

Read-only NWN:EE89.8193.37-17 x64 target:
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original installation and Ghidra project were not changed. REA dossiers,
hash-checked original-instruction oracles and captures are in
`backups/animations/`; oracle programs remain under `scripts/`.

## Tile traversal finding

The earlier report's proposed tile-loop fix was unproven. The original
`ClippedLineSegmentWalkable1402bb580..1402bbf55` reproduces BOTH recorded limits
on the same loaded `tic01_f14_01` mesh, tile(5,10), orientation3. World origin
`[60.57569122314453,104.85014343261719]` and destinations
`[23.887226104736328,88.91413116455078]` /
`[51.4035758972168,100.86614227294922]` reject with result0 after512 iterations.
The observed native face sequence enters the same10/18 cycle.

`inspect-native-tile-traversal.py` executes the complete original traversal,
clipping2bbf60, intersection2bf510, vertex getter2bf060 and plane22de80.371 cases
(209 synthetic,162 installed) match status, all written clip/height float bits,
and limit decisions. `verify-installed-tile-traversal.mjs` reloads original
resources and independently repeats the current implementation comparison.
It passes with2 matching native limit rejections. Asset arrays cross only an
in-memory Node/Python pipe; no installed mesh arrays/assets are saved.

Geometry behavior is unchanged. The expected native rejected query now records
`geometry.tile-traversal-limit` as a warning, with model, tile, orientation and
both input points, rather than manufacturing a fatal session exception. Each
occurrence remains recorded. The guard was not raised or bypassed, and no route
or destination was fabricated. Complete native mesh loading and whole-area route
selection are separate owners; this comparison uses identical loaded inputs.
Initial oracle failures identified an incomplete vertex-helper range and the
stack-cookie boundary. The first numeric comparison discarded signed-zero mesh
values through JSON; the accepted v4 pipe preserves their IEEE bits and has
zero bit mismatches. Failed captures are retained.

## Original combat owners and integration

| Owner / call site | Implementation and evidence |
| --- | --- |
| ResolveOnHitEffect `1403e7840..1403e8bbc` | Reusable dispatcher for selected passive types36/48/67/72, native subtype switches, critical gates, parameter table reads, chance/duration, cost-table24 DC and rules fallback, racial/alignment/lock gates and saves.1312 complete original-owner cases compare call order and arguments. Lower handler effects are captured independently. |
| On-hit tables `1402b937e..1402b93c3` / `1402b9578..1402b95bd` | Native loads IPRP_ONHIT into+3c8 and IPRP_ONHITDUR into+3d8. Runtime uses active resolver tables and existing cost-table lookup, with explicit missing-table errors. Physical rows/defaults stay data driven. |
| ApplyOnHitSlow `1403e1c40..1403e1ea5` | Queue instant visual95 first in attack list+b0, then Slow3 plus visual207 in a linked40 payload. Duration is float32(rounds)*6, packed flags9. Complete original owner, copy constructor, SetLinked/UpdateLinked and integer setter execute in60 cases, including partial allocation cleanup. |
| Creature event5 `14038e51e..14038e565` | Linked40 writes canonical object+180=1, passes loading0/special1 to ApplyEffect, then clears the flag. Other effects use special0.1007 bounded original event/post-handler cases cover raw flags, word type narrowing and null payload. |
| ApplyEffect flag tail `14048e3ce..14048e68b`, `14048e907..14048e934` | Exact consumed1 plus linked40/special1/flag1 removes that shared effect ID. Retained mechanical effects clear the flag; type67 and ordinary visuals preserve it. Visual IDs153..180,182,242..244 clear it. Known retained/linked application paths integrate this tail with real child application and removal. This is not a claim that every generic ApplyEffect admission branch is complete. |
| OnApplyDamage `140428bce..140428c09` | Native defender/attacker broadcast+initiative precede RemoveCharmEffectsByFactionID(defender,attackerFaction,-100), then RemoveSleepEffects before damage history. The runtime now follows this order instead of rejecting all type8 effects. |
| RemoveCharmEffectsByFactionID `14039e0d0..14039e2d6` | Scan live effects for temporary type8/kind1 or7, canonical creature creator and matching faction; immediately add source personal reputation(delta,decay1,180s), collect IDs, remove them in order afterward. |
| RemoveSleepEffects `14039eb90..14039ecab` | Sorted scan stops above type8. Remove kind9 sleep and restart live traversal, except integer1==1 sleeps survive once; a second scan clears their protection marker. Other control kinds remain. |

The charm/sleep owners have350 complete original-code cases with lookup/cast,
reputation mutation and shared-ID removal captured. The charm owner has a fixed
16-ID native stack buffer. Overflow is undefined native behavior; the client
diagnoses a17th match after preserving the defined prefix. Sleep removal also
diagnoses a callback that leaves the same live effect rather than spinning.
These are explicit safety boundaries, not claims of native undefined-memory
behavior. Faction/creator IDs remain canonical; no spell-specific outcome is set.

The dispatcher mirrors native method selection; it does not prescribe authored
spell behavior. Creature-weapon level drain reads the victim's signed cached
**CON** modifier D3d. An early proposed charisma name was corrected against
existing native cache evidence before integration. Knock compares placeable+3a8
before door+41f; synthetic boundaries are classified using their actual casts.

Only ApplyOnHitSlow's effect-producing handler is newly integrated. Other named
handlers, GetCanSlayAlignment and the door+41f binding retain specific diagnostics
when an admitted branch reaches them. This replaces the blanket property error
with correct chance/save/selection behavior, not silent skipped effects. Completing
those owners remains required for combat acceptance.

## Installed and UI validation

- `installed-fear-cast-v5.json`: **PASS six checks**. Both move-away commands,
  real frightened/turned StateScripts NCS and natural cleanup still pass. The
  untouched installed Fear impact executes through an ordinary native cast action
  with its explicit script cheat flag; seed1 passes the real save gates, and the
  target queues fleeing and moves beyond5.8m from a2m start. Attack/damage and
  linked delivery continue without new runtime errors. This isolates acquisition;
  it does not prove the imported cleric legally knows or prepares Fear.
- `installed-onhit-slow-v1.json`: **PASS two checks**. The actual equipped
  property48/subtype9 reads active on-hit/duration/DC tables and real saves.
  Seed1 admits an actual12-second linked payload. Combat event5 sets/clears
  offset180; vulnerable target retains Slow/controller/visual and recovers on
  natural expiry. Real immunity9 rejects Slow and removes the associated visual
  by shared ID. Registry objects/IDs/cursor remain stable. Individual owners are
  isolated from attack admission here; the broader Fear scenario covers live
  cast/combat processing separately. No renderer sampling is claimed.
- Full suite v2: **1968/1968 pass**. The first full run had one stale spy expecting
  the old two-argument adapter; it now asserts native loading/special arguments
  and linked flag lifetime as well as payload timing and duration metadata.
- Final build v2 passes with the existing bundle-size warning. Live casting UI
  v1 passes spellbook, right-click self cast, slot consumption, F2 world targeting,
  cancellation, cast animations and counterspell mode22. Final-build v2 UI also
  passes, `on-hit-status-ui-v2.txt`, session9728 terminal0 consumed.

All earlier failures and diagnostics remain retained. Final Fear runtime warnings
include trap detection, speech overhead/sound recipients, the native tile query
limits and corpse/body-bag scheduling. The isolated Slow probe retains a stat
effect presentation warning. Baseline missing `plc_w02.pwk` stays in load diagnostics.
No runtime errors are suppressed to make either probe pass.

Current spell dependency audit remains v53:54 unbound commands/22 missing scripts;
binding presence is not implementation proof. Next work includes the remaining
on-hit owners, death/corpse lifecycle, trap and effect presentation gaps, remaining
spells and the full single-player campaign. Multiplayer work remains deferred.

Verified checkpoint `backups/on-hit-status-1968-20261017-v1.zip` contains
10655 files /146926706 bytes; every archived length/SHA256 was checked.
`on-hit-status-checkpoint-v1.txt`, session4744 terminal0 consumed. This note
was added after sealing. All validation jobs are terminal; the goal stays ACTIVE.
