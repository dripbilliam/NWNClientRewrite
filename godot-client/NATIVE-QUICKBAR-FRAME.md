# Original quickbar frame — partial UI parity

The native quickbar now uses the original `PNL_QUICK_BAR` attachment points and
the twelve-entry `QB_BUT67` / `QB_BUT66` / `QB_BUT67END` table recovered from
`CPanelQuickBar` construction at `1408584a0`. This replaces the generic50×58
buttons and the single stretched slot background. The shared spellbook slot
presentation remains separate.

The original `Slot01` through `Slot12` hooks provide horizontal positions
0,67,133,200,267,334,400,466,533,600,667,733. Slot artwork keeps original mesh/UV
geometry; native up/hilite/down poses use the shared original button painter.
Source model icon/count/text hooks place the action icons and labels. Primary
action icons occupy32×32 with aspect preserved. Counts use the original white,
right-aligned default-dialog font. Function labels use that font and the
original bank prefix references68688/68689 rather than generic page buttons.

Original callback `140860010` centers the800-pixel bar at the bottom and attaches
`GUI_QBAR_ENDS` for wider screens. Native canvas transforms retain that anchor
at125% scale. End caps/background are input-transparent: outside clicks, WASD
and middle mouse can reach world input. The native frame prepares lazily after
the quickbar becomes visible and stops its own preparation polling once queued.
Its shared asset/art owners still publish asynchronously on bounded workers.
Desktop diagnostics expose readiness and explicit failure through `quickbar_skin`.

The existing action owner remains responsible for36 server bindings,12 visible
slots, F1–F12, temporary Shift/Ctrl banks, targeting, assignment menus, private
drag payloads and stale-owner rejection. Native frame changes do not fabricate
server outcomes. A real GUI shortcut move retains the existing pair of typed
assignment requests: destination assignment followed by source clear.

## Evidence and verification

Root `backups/animations/rea-native-quickbar-frame-v1.json` retains12 original
construction, anchor, icon and count/text analyses with original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only original model-node metadata is retained in
`reports/native-quickbar-model-parts-v1.json` and
`reports/native-quickbar-endcaps-parts-v1.json`. Those metadata runs predate
implementation and are research evidence, not current-source acceptance.

Current-source unchanged-source debugger receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-quickbar-frame-final-v1` |43| Original hooks/model table/font/counts; actual isolated hover/press/cast/F-key/right-click/drag; stale owner; modifier restoration;125% anchors;800px end-cap condition; outside movement/camera input; disconnect cleanup |
| `native-quickbar-character-final-v1` |55| Character-sheet resize/selection/art/shared painter regression |
| `native-quickbar-desktop-final-v1` |41| Existing native menus/targeting/actions |
| `native-quickbar-examine-final-v1` |62| Shared original scrollbar/Identify regression |
| `native-quickbar-store-final-v1` |32| Merchant/confirmation regression |
| `native-quickbar-retirement-final-v1` |13| In-flight native render teardown |
| `native-quickbar-playability-final-v1` |1314| Existing headless regression aggregation |
| `native-quickbar-actions-final-v1` |99| Original-server authoritative localhost5125 regression |

Normal, hover, held and125% native screenshots were inspected. Physical pointer
warping/capture and public connections are not used. A first43-check candidate
failed two test expectations: a nonexistent swap packet name and comparing
different model hit rectangles rather than icon anchors. Actual recorded move
requests were already correct; the retained failing report is not acceptance.

## Remaining gaps

Full quickbar and HUD parity are **false**. Exact original text baseline and
hit/capture boundaries, all enabled/disabled/ghosted/encouraged states, empty/
count/metamagic/secondary-icon variants, quickbar settings/EE alternate layouts,
tooltips, assignment trees and all role/server variants need original-client
visual/input comparison and a complete action audit. The current native frame
does not establish these by matching a screenshot or passing a narrow suite.
The earlier intermittent blood-model viewport assertion remains open separately.
The full UI goal stays active; general porting remains deferred.
