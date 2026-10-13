# Local movement and door checkpoint

Target: NWN:EE `89.8193.37-17`. Validated 2026-10-11 with the existing local installation, live Ghidra HTTP bridge, synthetic tests, and the bundled Electron renderer. No original binary, assets, or Ghidra annotations were changed for this checkpoint.

## Observed in the target binary

- `CNWDoorSurfaceMesh::LoadWalkMesh`, `0x1402cf720`, requests resource type `0x804` (2052/DWK). It recognizes geometry node names containing `_DWK_wg_closed`, `_DWK_wg_open1`, and `_DWK_wg_open2`, assigning state slots 0, 1, and 2. It stores vertex/face/material arrays separately by state. Direct string references are at `0x1402cf9ed` (`_DWK_wg_`, string `0x140dc9cd0`) and `0x1402cfaac` (`_DWK_dp_`, string `0x140dc9cf8`). These findings were read from live decompilation and cross-references, rather than inferred from screenshot appearance.
- The same loader handles `_DWK_dp_` dummy positions independently of collision geometry. These interaction points are not yet consumed by the replacement.
- `CNWSDoor::LoadDoor`, `0x1404208a0`, reads `GenericType_New` first and falls back to `GenericType` when absent. It reads `AnimationState` as a byte and passes it to `SetOpenState`; the string reference is at `0x140420978` (`0x140de75d0`). The replacement now prefers the newer appearance field too.
- `CNWSDoor::SetOpenState`, `0x140423230`, dispatches distinct animation IDs for state 0 (`0x16`), 1 (`0x32`), 2 (`0x33`), and 3 (`0x48`). A change to a non-3 state calls `CNWSArea::BudgeCreatures`. The replacement conservatively refuses a change when the new collision would overlap the player; it does not implement the game's creature displacement.

Existing Ghidra names were sufficient. Future annotation changes are authorized by the user subject to periodic backups; take a project recovery point before the first write.

## Observed in installed resources and replacement checks

The headless tool reads MOD, HAK, KEY, and BIF files in place. `ww_resources.hak` is required to resolve the entry ARE; the initial MOD-only probe correctly failed without it. The smoke tool automatically includes shipped HAKs and asserts that required HAKs are present.

| Witch's Wake area | Tiles | Walkable faces | Active object faces | Unavailable object meshes | Visible doors | Tested open/close cycles |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `modulestart001` | 42 | 1,223 | 82 | 9 | 0 | 0 |
| `angmarshouse` | 6 | 100 | 117 | 4 | 2 | 2 |
| `brogansarm` | 60 | 932 | 252 | 0 | 13 | 7 |

- Each area resolves every tile WOK and accepts sampled valid capsule movement. The entry's nine unavailable PWKs are scorch-mark decorations; Angmar's four are hanging shields. They remain explicit diagnostics rather than inferred collision geometry.
- Installed files use `#NWmax WALKMESH ASCII`, `#NWmax PWKMESH ASCII`, and legacy `#MAXMODEL ASCII` PWK headers as well as the previously accepted headers. Legacy PWKs can contain `NoWalk` node names or no geometry, so state/node naming cannot be used to reject these exporter variants.
- `t_door01.dwk` and other visible door resources contain different closed/open1/open2 geometry. Real-data smoke checks locate a route blocked by the closed leaf, clear it with open1, then verify blocking returns after closing. This tests the door collision in isolation, not full route traversal or script behavior.
- The Electron smoke tool opens the module's entry and then `angmarshouse`, verifies its movement HUD and area caption, checks renderer console errors, and captures an offscreen screenshot. The local screenshot is under ignored `backups/movement-doors/angmarshouse.png`.
- Synthetic regressions cover separated/rotated DWK states, exporter headers, narrow floor gaps, tile seams, slopes, rejected excessive steps, narrow passages, stacked floors, grazing walls, stationary overlap, locks, missing states, and interaction distance/height.

## Implementation and remaining questions

Movement subdivides requests into at most 0.08-unit horizontal steps. Each center/perimeter probe checks continuous projected triangle coverage along the step, with height limits, so a missing floor interval is detected even between sampling positions. Object collision clips triangles to the body's vertical span and sweeps a horizontal disk; this catches wall grazing and overlap that the earlier handful of ray samples missed. The capsule radius is consistently 0.22 units. Spawn candidates use the same support/overlap checks. Held keys are cleared on blur, visibility changes, and control focus.

These are replacement algorithms, not evidence of exact NWN movement parity. Perimeter support uses eight directions; swept vertical spans are conservative on changing heights, the 0.9-unit step limit is still a preview choice, and exact floor connectivity, creature collision, and performance across large modules remain open. Decorative objects without PWK resources do not get invented blockers.

Door state is local, respects serialized lock flags, and lasts through development area switching in the current module. Closed doors display their existing static MDL; open doors hide that closed pose and display the selected DWK as a translucent proxy. Actual animation, sounds, event scripts, lock/key actions, invisible transitions, and linked-area movement are not implemented. Blueprint-only fields are not merged from UTD resources yet. The module entry area contains no doors; completing a real route from it requires trigger/script/linked-object traversal.

Next: index destination door/waypoint tags, retain invisible transition objects, place the player safely at linked destinations with facing, and replace development dropdown navigation for the representative route. Verify script and transition event behavior in the target before claiming gameplay parity.
