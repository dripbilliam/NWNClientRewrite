# NWN-84 pregame Options failure presentation

`native_pregame_menu.gd::refresh()` now selects the active `main` or `options` page before reading its existing exact `cohort_snapshot().failures`. The two-line change retains the previous main-page message and shows `options_pregame+okcancelpanel` plus the failed image/font key when Options artwork cannot finish. The page remains hidden until its cohort is ready. No asset request or admission order changed.

Checks:

- `tools/nwn84/options-failure-gate-test.gd` → `.cache/nwn84-options-failure-gate.json`: 6/6 headless injected-state checks. They cover exact image failure key, exact font key/cause, pending message, ready admission, and main-page failure regression.
- Installed original content, no-focus secondary graphical correctness fixture `tools/nwn84/options_original_content_test.gd` → `.cache/nwn84-options-after-failure-status.json`: success, 5/5 models, 34/34 images, 10/10 fonts, visible first Options page and ready/visible reopen. This is a navigation and artwork readiness check, not an FPS or original-client visual comparison.

Independent root reruns: `.cache/nwn84-options-failure-root.json` passed 6/6, exit 0; `.cache/nwn84-options-failure-original-root.json` passed graphical original-content admission with 34/34 images, 10/10 fonts, zero pending/failures, exit 0.

The standard Godot invocation reported local `user://` logging/shader-cache and root-certificate diagnostics, but both fixture processes exited 0 and their result files passed. These diagnostics are separate from the asserted menu behavior.
