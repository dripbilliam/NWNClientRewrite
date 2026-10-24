# Native camera modes

Options → Game now selects Top-down (1), Chase (0) and Stiff chase (2).
Godot owns the follow state and its frame calculations. The JS host supplies
authoritative creature poses, cached appearance HEIGHT and current-connection
server mode messages; it does not calculate the camera every frame.

`systems/game_camera_state.gd` retains the original single-precision follow,
quaternion interpolation, steering, manual latch, rate and pointer calculations.
`systems/camera_controller.gd` converts NWN Z-up positions and wxyz quaternions
to Godot world transforms, including when the camera has a transformed parent.
An exactly unchanged view skips the transform assignment; no approximate pose
snapping is introduced. The imported view supplies the initial pose.

Middle drag orbits, the wheel zooms, Home/End turns, Insert/Delete tilts and
Page Up/Page Down zooms. Keyboard turn/tilt rates are ±75 and zoom is ±7.5;
pointer impulses scale with viewport width as in the original. Native steering
keeps its chase dead band and manual-input latch. Text entry and focus loss
release held camera keys. Movement and middle drag continue with Options and
inventory open. Captured/offline free-camera controls remain available.

The selected mode persists under `[camera] mode` in native preferences. Invalid
stored values fall back to Top-down. A valid current server mode updates the
view and selector without overwriting the saved preference. Retired connection
messages and invalid mode bytes are ignored. Manual yaw, pitch and distance
survive area replacement; a controlled-object binding refresh uses the current
view rather than an older area snapshot.

## Original reference and evidence

The retained isolated observations identify original nwmain SHA-256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
They execute Follow `0x55100`, mode/steering `0x7d0d00`, `0x7d0ab0`,
`0x7d1c90`, pointer/rate paths and setters yaw `0x7cfe60`, pitch `0x7cfdb0`,
zoom `0x7d4340` against synthetic state. Scene accessors, dependency bookkeeping,
virtual setters and finite CRT math are recorded boundaries. This milestone
reuses those observations; it does not modify or attach to the running original.

`tools/prepare-camera-core-oracles.mjs` verifies the target and source hashes
before preparing `tests/fixtures/camera-core-original-v1.json`. The original
inputs remain in `backups/animations/native-camera-observations.json` and
`native-camera-rate-flags-observations.json`. They contain 432 follow frames,
720 steering observations, 100 pointer observations and 403 rate observations.
The native oracle report `reports/camera-core-oracle-v1.json` passes 16,593
numeric/state comparisons over those 1,655 observations plus authored cases.
Those comparisons are not independent live gameplay tests.

`reports/camera-mode-ui-v7.json` passes 24 rendered Vulkan checks, including
actual pointer/keyboard dropdown selection, persistence, transformed-parent
orientation, unchanged-view assignments, held input, text/focus release,
current/retired server-mode delivery and current controlled-binding pose reuse.

`reports/native-camera-mode-local-v4.json` passes 23 camera checks plus 16
dialogue/examine checks against owned `127.0.0.1:5121` GodotFeedback1. Three
animated admissions traverse dense_a → dense_b → dense_a. Each mode's actual
displayed selection, follow pose and steering policy is recorded. WASD and
middle drag operate with two menus open; manual view values survive both
transitions exactly, old camera owners are released and the user preference
file is unchanged. Screenshots show Chase and Stiff chase selected correctly.
The client exits 0, disconnects cleanly and has no rejected commands or native
engine errors. This is functional evidence, not a clean FPS benchmark.

The first local run exposed a real area-lifetime race: an in-flight particle
frame could arrive after its owner had retired. `tools/particle-input-scope.cjs`
now recognizes only actually allocated epoch/scope pairs. Known retired render
requests drain without starting work or touching the current world; unknown or
forged scopes still reject, and current payloads retain normal validation.
Gameplay commands do not use this exception. Native particle requests include
the transfer ID. The final run records one naturally late request and two
deliberately delayed requests from real retired areas; all three worker epochs
close with zero pending jobs and zero remaining threads.

`reports/camera-mode-node-v2.log` passes 139 backend tests, including the
original camera suites, strict live-evidence gates, particle retirement and
existing settings/actions/inventory/spellbook/shortcut regressions.
`reports/camera-settings-ui-regression-v1.json` passes 21 existing settings GUI
checks. `reports/native-camera-feedback-regression-v1.json` passes 20 feedback
and 16 dialogue checks with actual damage messages, unchanged preferences and
clean shutdown.

Earlier reports are retained rather than rewritten. Local v1 failed on the
retired particle race. Local v2/v3 passed narrower gates before recording the
selector's displayed ID; v4 supersedes them. GUI v5 failed because emitting a
popup signal did not select the OptionButton. The current driver performs
native pointer/keyboard selection. Early dependency checks caught indentation,
Node viewport API and type-inference errors. One dependency-check process
crashed with 0xc0000005; the cause is unestablished and subsequent dependency,
GUI and live runs did not reproduce it. None of those failures is promoted.

## Remaining camera work

This ports the mode/input/follow core, not the complete original camera system.
Scripted location, store/restore, explicit height overrides, locks, attachments,
clear-view/collision/keyhole behavior and cutscene gates remain pending. Current
server mode delivery has authored receipt tests; an actual scripted server-mode
fixture and preference reuse across a second live login remain unaccepted.
Broader shape/height/strafe integration, initial attachment/clear-view policy,
physical-device review and exact camera fidelity need additional coverage.

The existing models, textures and UVs are preserved. Complete UI → rendering →
combat migration and sustained moving-scene 60 FPS acceptance remain open. No
public server was contacted. Reproduce the local check while GodotFeedback1 is
active with `./godot-client/join-local.ps1 -CameraSmoke -Report unused-name.json`.

The subsequent command port adds original location/store/restore/height/locks/
limits/flags math and basic attachment routing, with 10,434 native-oracle
comparisons passing. Its first live command test timed out because the test
looked for plain chat text rather than received rich text; the corrected test
has not yet been promoted. The user then prioritized NWSync. The new code is
saved as work in progress; scripted command, scene attachment/clear-view and
collision parity remain unaccepted. NWSync testing also identified and removed
a retained static camera lookup initializer; both original numeric suites pass
after replacing it with an immutable constant.
