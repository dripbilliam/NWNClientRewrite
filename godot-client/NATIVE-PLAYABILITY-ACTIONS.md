# Native multiplayer actions and NUI

The direct Godot entry now has real localhost evidence for equipment, potion
use, spellbook/quickbar casting, preparation, party membership/commands, merchant
transactions, level-up, combat feedback and action cancellation. These are
original-server outcomes; the UI does not apply character advancement, move
items, spend gold, consume spells, roll attacks or remove queued actions locally.

Direct-native combat follow-up: [NATIVE-COMBAT.md](NATIVE-COMBAT.md) records
62 local gameplay checks including actual cast/attack rig playback, GPU skin
deformation, original model `hit` events and unchanged server authority. Complete
effects/projectiles/audio and mixed-original-client parity remain open.

## Current ownership

| Concern | Native owner | Transport boundary |
| --- | --- | --- |
| Party, quickbar, record, spellbook, map, journal, radial | `systems/native_game_desktop.gd` | Typed action requests, raw replicated state |
| Equipment, containers, merchant confirmation/prices | `systems/native_inventory.gd`, `server_store.gd` | Original item/store requests and server responses |
| Level-up choices and original table rules | `systems/native_level_up.gd` | Server snapshot, class availability, proposal, acceptance |
| Queue icons and cancellation | `systems/server_action_queue.gd`, `native_data/game_ui_rules.gd` | Original action/group IDs; server deletion removes the widget |
| Combat/chat and overhead prompts | `systems/native_data/combat_feedback.gd`, `native_gameplay_ui.gd` | Raw CC3/5/6/8/11/14 fields; original TLK/table presentation |
| Scripted NUI state, layouts, input, images | `systems/native_nui.gd`, `native_data/nui_state.gd`, `nui_projector.gd`, `server_nui.gd` | Raw NUI messages and typed event/bind requests |
| Resource-backed NUI | Native asset service, native JSON parsing | `deferNuiResources` prevents the protocol process from preparing JUI |

The previous JavaScript UI services are references only. The protocol process
still performs authentication, downloads, packet encoding/decoding, raw state
merging and transport framing. It rejects rendering/UI staging imports. Native
NUI retains a window serial across area changes and checks it before sending.
Layout replacements invalidate stale control handles. Lists prepare a bounded
visible range, including indexed edits sent as a whole binding plus row index.

Trade requests now mark their item pending immediately, preventing repeated
clicks from sending duplicate requests before the next displayed inventory
refresh. Transaction responses release that pending state. Rejection/timeout
paths remain explicit. Source state, displayed views and server results are
different milestones; tests wait for the displayed view before its next click.

## Evidence and reproduction

Run from the workspace root:

```powershell
./godot-client/tools/test-native-actions.ps1 -Run unique-actions-run
./godot-client/tools/test-native-actions.ps1 -Nui -Run unique-nui-run
```

This helper starts an isolated original server on port **5125**, with public
listing disabled, and stops only its own verified process. It preserves the
Prelude server, original client/editor, saved characters and user preferences.
The fixture module/JUI files are authored data; installed models/textures/items
are referenced by resref. The installed sample BIC receives test XP in memory;
only metadata from its final server export is written to the report.

Accepted original-server evidence:

- `reports/native-playability-feats-live-v1.json`: 55 checks. Equipment moves,
  one consumed potion, two real prepared Light uses, quickbar assignment,
  preparation clear/fill, henchman add/follow/remove, charged purchase and credited
  sale, repeated-click suppression, Wizard 15 to 16 then Fighter 1, native attack
  feedback, and server-confirmed cancellation. HUD Rest restores prepared spells; Summon Familiar
  and Unsummon change the actual server associate. The exported BIC confirms classes,
  abilities, skills, feats and learned spells.
- `reports/native-playability-nui-final-v3.json`: native root/open callback,
  watched text/checkbox/combo values, a distant virtual list row and indexed
  server echo, child menu, native resource-backed grandchild, full-height toolbar clamped entirely inside the viewport,
  server targeting callback, native image preparation and window close.
- Both run under the normal-heap CDB harness, with no public connections, source
  edits during the run, native exceptions, engine/lifetime errors or remaining
  worker threads. These are functional checks, not clean FPS benchmarks.

Native regressions: `native-ui-controls-v13` (41 original-art/UI checks),
`native-combat-feedback-final-v2` (17 formatting/disclosure/token checks),
`native-nui-projection-v1` (14 ownership/missing-value/virtualization checks).
The protocol/NUI/skill/raw-world suites additionally pass 59 Node tests, including
the existing original binary serialization/skill byte oracles.

Earlier failed runs are retained. The NUI failures exposed unsafe missing-value
comparisons and a copying helper whose name conflicted with Godot's built-in
method. A later JUI failure identified a missing authored fixture override;
the accepted run loads that override through native workers. Test-only failures
also caught clicks sent before displayed rows refreshed and incorrect expected
callback labels. They are not presented as accepted evidence.

## Limits and next migration work

This is not full binary parity. [Direct-native character creation](NATIVE-CREATION.md)
now owns choices, rules, BIC writing and original previews in Godot, with new-character
Prelude admission and server-table override checks. Original window chrome, every class/feat/item
variant, combat animations/effects and wider server/mod NUI remain acceptance
work. General combat feedback uses the verified descriptor branches; unported
arithmetic branches are diagnosed (branch 11 occurred locally), not invented.
The NUI spell-target selection path is connected, but the current authored child
fixture tests a generic server targeting callback rather than every toolbar
spell/assignment script. No automated Arelith/public connection was made.

Checkpoint before work: `backups/native-playability-actions-before-v1.zip`.
Verified action/combat checkpoint: `backups/native-actions-combat-after-v1.zip`.
Final checkpoint: `backups/native-playability-nui-after-v1.zip`.
The [final audit](reports/native-playability-actions-final-audit-v1.json) indexes
accepted reports and source hashes. Backups contain authored sources only.
