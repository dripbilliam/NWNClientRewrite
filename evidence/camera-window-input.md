# Camera rotation with floating windows

The user reported that opening a window blocks middle-mouse camera rotation.
The gameplay camera gate depended on OrbitControls.enabled and explicitly
rejected inventory/dialogue. Menu visibility callbacks disable OrbitControls,
so even exposed canvas space could not start or continue gameplay camera input.

Gameplay input now has its own gate, independent of floating window visibility
and viewer orbit controls. Character creation, external modal capture, cutscene,
transition/loading, shader warmup and unready/disconnected network states still
block it. Mouse listeners remain on the canvas: menu buttons and scrolling keep
their own hit targets, while middle drag and wheel over the world operate the
camera. Camera rate math and native camera-lock flags are unchanged.

Thirteen focused tests pass, including execution of the actual production gate
with GameCameraInput pointer events: several open menus with orbit disabled,
opening inventory during a drag, pointer release, left/right button exclusion
and blocked lifecycle states. Existing native camera/mouse-rate and movable
window checks pass. First test run caught a missing optional player access for
a transition-only session; corrected before the final passing run.
Build index-DFgtWRfp.js / index-8ID_vg9F.css passes. Reports:
backups/animations/camera-window-input-tests-v2.txt and camera-window-input-build-v1.txt.
No live client restart, remote input or server connection was performed.
The broader goal stays paused; changes remain unsealed after checkpoint49.
