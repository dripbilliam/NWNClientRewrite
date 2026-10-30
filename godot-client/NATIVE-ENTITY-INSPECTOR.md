# Entity diagnostics and compound animation types

2026-10-27. User reported NPCs walking without animation, including Skrul'nak the
Barfly, and authorized adding an inspector/export tool. No automatic public
connection, client restart or game command was performed during investigation.

## Evidence and animation correction

Session `native-session-1793142869178` has no explicit animation failure in its
engine log, but its timing output omits named actors and selected clip metadata.
Absence of that error is not proof of working playback. The user's screenshot
shows the character model present, with green selection highlighting.

`reports/native-skrul-npc-host-json-v1.json` records a bounded read-only memory
lookup in this owned session's protocol host: NPC ID2147583538, area2147583247,
appearance388. Two complete received JSON candidates have animation codes0/40.
Heap remnants can outlive their source: these establish received candidates, not
the instantaneous registry or active Godot clip. No credentials or unrestricted
memory windows were serialized. Earlier Godot UTF8/UTF32 searches yielded no
complete NPC JSON; do not treat their negative result as absent server data.

The historical sealed server catalog `capture-pUQlR4/catalog-1` records
`appearance:2017` SHA256
2c03e71862f3eda2d0e9d9049ec637a8420b942a8b8392626630cefbe2ddfc04.
Row388 is Gnoll_Warrior, RACEc_gnoll, MODELTYPEFW. Its identity against the active
session's currently resolved table/model is not yet verified. The frozen corpus
contains availability but not c_gnoll's payload; no guessed substitute was added.

The native lookup previously classified only exact `P`/`F` strings as humanoid.
That is a confirmed semantic mismatch with the original binary's compound flag
handling. `animation_body_type.gd` now mirrors the recovered P/S/F/L priority and
body categories1/2/3; `animation_lookup.context` retains the raw type for inspection.
FW selects body1 and pause1/walk/run, instead of cpause1/cwalk/crun. No creature
ID, server name, model or clip-name fallback is hardcoded into production.

Read-only oracle: NWN:EE89.8193.37-17 x64, nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
`../backups/animations/rea-gnoll-animation-body-refresh-v1.json`:
FUN_1409795c0 body0x1409795c0..0x140979d08, CExoString::Find call sites
0x140979b82/0x140979b9a/0x140979bae/0x140979bc2/0x140979bd8 and setter call
0x140979c57. `rea-gnoll-animation-body-setter-v1.json`: FUN_14080a2d0 writes
the supplied byte to creature+0x2fc and animation-owner+0xde. Recovered control
flow supports the classification; these are not native runtime timing findings.
Actual Skrul'nak visual acceptance remains pending a restart/live export.

## Using the inspector

Main Menu / Options / Performance / **Entity inspector…**. Search an NPC name or
object ID, select it, then **Export entity JSON**. **Refresh** updates current
playback; turning off **Creatures only** also permits other entity types.
Exports go beside the session report in `godot-client/reports`, with unique entity
ID/time filenames. In a graphical client the full path is copied to the clipboard.
The draggable panel remembers its position; Escape closes it. Only its rectangle
blocks world pointer input. It does not issue gameplay/server commands.

Exports contain identity/generation/area, copied appearance and selected received
movement/animation fields, resource names/animation-source identities, rig context,
requested and active clips, available/instantiated clip names, playback time/speed,
loop and serial, existing missing-clip diagnostics, processing and visibility.
They never advance playback or instantiate lazy clips. There is no per-frame
inspector scan: refresh/selection/export are explicit actions. The panel rejects
export when the entity departs, world instance/generation changes or world retires.
Session reset closes it and clears stale selection.

## Validation and limits

Headless normal-heap CDB receipts:

- `native-entity-inspector-final-v1`:20 authored actor/door snapshot, UI selection,
  export, copied-state, unchanged-clock and generation/departure/reset checks.
- `native-animation-body-flags-ready-v1`:37 exhaustive recovered flag-branch,
  extra-W, case-sensitivity and actual server-table context/lookup checks.
- `native-entity-inspector-options-final-v1`:38 Options checks, including a real
  button click emitting one local inspector request.
- `native-entity-inspector-playability-v1`:1314 existing animation/input/
  transition playability regressions.
- `native-entity-inspector-menu-v1`:native session menu startup under CDB,
  with zero public connections. No local gameplay connection is claimed here.

The first flag test used an incorrect run-code expectation3; its retained failed
receipt was corrected to the original lookup's code4, not waived. No graphical
benchmark or second game-server client competed with the user's open session.
Read-only memory lookup and headless correctness work can still consume CPU:
manual FPS during these intervals is not controlled performance evidence.
Existing runtime scripts remained loaded while the on-disk next build changed;
the old session's eventual source-unchanged gate is expected to fail. It must not
be relabeled a clean current-build test. Keep the raw logs for historical scope.

The earlier live particle spikes are separate: retained frames112.197/115.512ms
include particle callback75.926/64.938ms respectively. A later observation may
show particles disabled after those frames; rolling worker summaries are older
windows. Do not count repeated worst-frame observations as separate stalls, or
attribute this animation bug to particles based only on those timings.
