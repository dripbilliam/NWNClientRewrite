# Seven-defect UI/camera source changes

Prepared and checked in isolated headless projects after local-check approval.
No native build, GPU/visual test, server connection, restart or live-session
mutation was performed by this lane. Existing edits in
shared settings/options were retained; exact before-bytes and git diff are in
`.cache/native-140fps/particles-agent/native-parity-ui-before-v1/`.

## Field of view

`camera_fov_projection.gd` uses the native module-created gameplay default of
**45 degrees vertically**. Native evidence supplied by the render agent:
Camera ctor1400571f0 and NewCAurCamera140059f70 initialize viewAngle+4c8 to
0x42340000. CNWCModule::LoadModule1407cd2c0 creates the camera and its later
vtable+0x80 call resolves to SetClipDist14005b440, leaving that FOV unchanged.
Camera::RenderScene14005a5d0 uses actual viewport width/height, Y=tan(angle/2),
X=Y*aspect. This establishes the default at module camera creation; later user
or scripted overrides are not ruled out by that chain.

Client Options stores `rendering.fov_degrees`, with a20–120 degree slider and an
explicit Original reset. That adjustable range is a client UI policy, not a
claim about a native hard limit. Graphics is scrollable to avoid adding another
clipped options page. The slider is integer degrees; the range normalizes any
manually edited fractional saved value consistently with its displayed value.

`camera_fov_binding.gd` holds weak settings/camera references and no process
callback. It applies Godot KEEP_HEIGHT once per new camera and on explicit
option changes. Repeated same-camera snapshot boundaries do not overwrite a
later authored/replay camera FOV. Original reset always emits/applies, including
when the slider already reads45 but another owner changed the camera.

Root owns the entry integration and has added these source hooks:

1. Create binding and `configure(render_settings)` after settings setup.
2. After accepted raw-world `super.receive`, before ACK and after closing-check,
   call `binding.bind(camera)` if the camera is valid.
3. Call `binding.unbind()` at session reset. The camera can survive a reconnect;
   unbind drops only its weak reference/ID and retains the settings subscription.
4. Call `binding.close()` during shutdown.

No orbit/distance/position/camera animation behavior is changed.

## Invisible blockers option

Settings exposes `show_blockers_enabled`, signal `show_blockers_changed(bool)`,
and config `rendering.show_blockers`. Default is false, and wrong-typed saved
values cannot enable it. The diagnostic checkbox is in Performance. Classifying
and publishing the actual helper/blocker visibility is owned by the render
lane; this lane does not infer it from transparency or server interactability.

## NPC conversation clipping

The old frame computed clearance from physical viewport height minus local
dialog position. A scaled parent canvas therefore overstated logical space.
`conversation_viewport.gd` derives parent-local bounds by the canvas inverse and
clamps the dialog in that same space. Normal native360px width,64×100 portrait
and20px/311px reply split remain unchanged. Extremely small logical viewports
use a uniform constrained-only fit, retaining portrait/art aspect and native
rail geometry instead of clipping it.

The shared frame explicitly wraps body/replies at their actual scroll viewport
widths. Reply hit heights are invalidated on text/font/width/minimum-size changes
and reread after layout; replacement serials keep their original input fencing.
Horizontal rails remain hidden while permitting the viewport to shrink. The
previous DISABLED mode propagated the child's old minimum width, preventing
331px text from ever reaching the narrower-width wrapping path.
The unchanged native `conversation_layout.gd` still owns original content flow,
animation poses and scrollbar layout. ServerConversation reply IDs, pending,
abort/terminal behavior and protocol actions are not changed.

Focused native headless checks:

* `tests/native_parity_camera_fov_test.gd`: settings/reset/persistence, camera
  replacement, same-camera ownership and real projection aspect convention:
  **27 checks, exit 0** in `parity-headless-v2`.
* `tests/native_parity_blocker_setting_test.gd`: default off, bool persistence,
  signal and malformed-value fallback: **4 checks, exit 0** in
  `parity-headless-v1`.
* `tests/native_parity_conversation_viewport_test.gd`: canvas scaling, bounded
  fit, real RichTextLabel wrapping/hit height, dynamic rows, disabled/pending
  protocol ownership and portrait stretch convention without game assets:
  **23 checks, exit 0** in `parity-headless-v3`.

`run_headless_checks.mjs` stages only the literal GD source closure into a fresh
private project and verifies source/private pins after each batch. It uses the
verified ce2d engine and no native outputs, source-project import or server. All
passing logs include the environment error `Failed to read the root certificate
store`; therefore strict clean-engine receipts deliberately remain false.
Earlier failed parse/width runs and exact before-bytes are retained. A renamed
helper constant avoids the builtin Projection name, and the fixture avoids the
builtin Skin name. No other script/engine/leak errors remain in successful logs.

The existing `native_conversation_policy_test.gd` native float32 oracle remains
unchanged. A dedicated subclass of the asset-backed
`native_conversation_ui_test.gd` passed **51 checks, exit 0** in the isolated
`conversation-art-v4` graphical project. Five PNG/state captures cover short
100/125% and long100/125/200% dialogues, real original fonts/portrait/native
scrollbars, long-reply scrolling, token expansion and reply/input ownership.
Original model/font/portrait byte hashes are in its functional validation.

The project set no-focus and secondary screen2 before creating the window;
every capture reports unfocusable=true, focused=false and visible mouse mode.
No physical pointer/focus operations, server session, native build or FPS test
were performed. All483 staged resource pins remained unchanged. The only V4
engine error is the same certificate-store environment error, so strict
clean-engine success deliberately remains false.

The old native fixture asserted that typing in chat emitted no messages at all.
Chat focus now correctly emits separate native-panel open/close notifications.
After an exact backup, only that obsolete assertion block was changed: reject
dialogue reply commands and preserve entry/serial/pending state, while explicitly
requiring both focus notifications. V3's old assertion failure and V2's stale
actor-source parse failure are retained. V4 additionally stages the literal
feedback JSON dependency rather than treating its absence as a product error.

This validates the isolated current artwork/layout/input path. Actual long
server dialogues, original-client visual comparison and full UI parity remain
separate checks.
