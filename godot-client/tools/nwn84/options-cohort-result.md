# NWN-84 pregame Options artwork cohort

`native_entry_menu_frame.gd` now admits `options_pregame` through the existing exact `cohort_snapshot()` gate. The gate covers the two original GUI layouts, recursively requested models, constructed images and button clips, fonts, and the hidden `okcancelpanel` confirmation. Its `_process()` path also emits `artwork_ready` on readiness or a named cohort failure. `options_main` and dynamic child pages retain their prior gates. The three-line source change and comment correction were included by an external workspace writer in commit `2246b714`; no further production edit was made afterward.

## Checks

- Installed original content, Godot 4.7.2 compatibility renderer, secondary monitor, no-focus: `.cache/nwn84-options-before.json` and `.cache/nwn84-options-after.json` both pass. Each has 5/5 models, 34/34 image placements, 10/10 fonts, zero pending/failures, first Options visibility only after readiness, and ready/visible reopen. The initial art gate never returned ready before the exact cohort. This checks content and admission, not FPS or visual parity with the original binary.
- `tools/nwn84/options_cohort_gate_test.gd` / `.cache/nwn84-options-gate.json`: 8/8 focused checks of cold admission, hidden confirmation, image/font failures, and reopening.
- Existing `tools/nwn84/premain_cohort_gate_test.gd` / `.cache/nwn84-premain-regression.json`: 9/9, confirming the shared main-page gate remains intact.

Independent root reruns on the committed source: `.cache/nwn84-options-original-root.json` passed the same 5/5 models, 34/34 images and 10/10 fonts on the secondary/no-focus OpenGL window; `.cache/nwn84-options-gate-root.json` passed 8/8; `.cache/nwn84-pregame-flow-options-root.json` passed 24/24 graphical navigation/session checks after the Options gate. All exited 0 with zero fixture failures. These runs use controlled art for the navigation fixture and do not establish original-client pixel or audio parity.

The exact Options failure is present in `cohort_snapshot().failures` and blocks admission. `native_pregame_menu.refresh()` currently shows a generic preparation message for Options failures; presenting the named reason in that controller is a separate follow-up outside this file's ownership. The installed-original run had no such failure.
