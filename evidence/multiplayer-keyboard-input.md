# Multiplayer keyboard input and radial stacking — 2026-10-20

W/S now request forward/backward drive, A/D turn, Q/E strafe; Shift selects
forward walking. Arrow keys alias forward/back/turn. Singleplayer retains its
existing keyboard adapter. Multiplayer input never writes replicated positions,
actions, animations or spell/combat state. The unchanged server resolves drive
movement, collisions, rates and interruptions.

## Original binary evidence

Read-only NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original binary and Ghidra project unchanged.

- Client1407bf980 sends6/29: FLOAT native X/Y, raw client area OBJECT_ID,
  12-bit heading in tenths of a degree, sequence BYTE, flags BYTE.
- Server140452ec0 reads those fields, checks controlled creature/area,
  commandability and8ac, clears special/action state and queues AddDriveAction
  14037e880 with groupFFFF and continuation2. The server owns all movement.
- Client1407bf040 sends bodyless6/33. Server140452ba0 clears continuation
  only on a commandable creature's head action33; it does not broadly cancel
  the next attack, spell or waypoint.
- Client1407c03b0 sends6/28 with two FLOAT orientation components for turning
  without translation. Input dispatcher1404531b0 validates and applies them.
- UI1406f1e40 uses250ms local updates/500ms drive refreshes, rounded normalized
  heading*10, native masks forward walk1/run3, backward2, strafe4/8, turn16/32.
  Its assembly, rather than the incorrectly propagated decompiler char, proves
  the flags. Turn-only applies30-degree increments. AIActionDrive1403b8b60
  independently confirms these masks. Reset1406e5da0 and key-up cases in
  1406ed720 send AbortDriveControl.

REA dossiers: backups/animations/rea-arelith-keyboard-*.json. Large dispatcher
and event-handler pseudocode was read through retained evidence; complete
derived text is kept alongside the dossiers. No original assets were copied.

scripts/inspect-native-network-drive.py executes the original three senders,
whole server drive/abort handlers and original scalar codecs.62 comparisons
cover movement flags, headings, sequence wrap values, stop/commandability/head
action and cardinal orientation. Transport, allocation, lookups, area access,
sticky-mode decisions and action insertion are captured lower boundaries; this
is not an execution of the complete server pathfinding/AI loop. Native unused
padding bits are masked explicitly in comparisons.

## Application ownership and UI

The typed preload/IPC keyboard request checks trusted renderer ownership,
session, current area generation and controlled actor. The session shares the
existing native movement sequence counter with clicks. Input queues capture
their owner and skip obsolete-area/session work. Release, blur, chat focus,
hidden document and modal capture stop drive. Opposed directions cancel while
held; aliases preserve still-held keys. Key repeat does not flood the server.

Keyboard bindings are the replacement's explicit defaults, not a port of all
original remapping, controller/group input, combat-step or client prediction
branches. Native position/animation feedback remains authoritative. This pass
does not replace the deferred movement interpolation/prediction polish.

The shared radial now uses a manual browser popover in the top layer, above
inventory, chat, spellbook and other stacking contexts, with a high-z-index
fallback. It retains viewport coordinates, explicit close/submenu/drag behavior
and blocks keyboard events from reaching panels beneath it. No implementation
or debug controls were added inside the game viewport.

## Validation

-69 focused node tests pass: native packet comparisons, keyboard lifecycle,
  unchanged canonical actor, trusted IPC, stale area/actor/session rejection,
  waypoint and existing session regressions.
- Hidden offline Electron check passes actual DOM keyboard capture, chat/blur
  stop, top-layer state, elementFromPoint priority against a maximum-z sibling,
  viewport coordinate alignment, Escape and action click. Derived result:
  creation-experience-keyboard-radial-ui-v1.json. Electron emitted GPU teardown
  diagnostics after the successful check; no fixture assertion/browser errors.
- Production build passes; creation-experience-keyboard-build-v3.txt.

Live acceptance: corrected run-v13, PID1332, Yrs on arena.arelith.com:5123.
Renderer key events were dispatched from the game canvas through the actual
capture/IPC/peer path.10 drive messages,5 stop messages and6 orientation messages
were sent. Server positions changed by1.765 units running,1.061 walking,
0.900 backward and0.456/1.126 for strafes (650ms holds, not a speed benchmark).
Each settled stop remained unchanged through the later sample. A/D changed
server yaw315→45→315 without translation. Zero invalid packets, renderer errors
or failed scene objects in the accepted run. Derived assertion-checked proof:
creation-experience-keyboard-live-proof-v1.json. The window subsequently closed
through its normal disconnect handler at09:20:02UTC (control-v10 remained false).
This is same-process scripted
renderer input, not a claim of desktop physical-key or original-client visual
comparison acceptance.

Earlier run-v11 exposed the adapter's array-only orientation conversion, which
halted rendering. The context now handles entry arrays, vector records and
quantized yaw, with regression coverage. Run-v12's Window-targeted synthetic
events exercised the wrong event phase and emitted harness errors; it is not a
WASD acceptance. Correcting the harness to use an actual game element reproduced
physical capture/bubble order. The offline UI check also asserts the older
singleplayer listener cannot consume multiplayer keys. Final UIv3 passes.

## Local drive prediction correction, 2026-10-20

The earlier packet-only acceptance did not establish smooth keyboard movement.
Original UI1406f1e40 ticks local input every250ms, sends translational drive
every500ms, and advances2d2/last-input2d3 even on an unsent local tick. Original
6ea9e0 makes400ms local lookahead;7fdeb0 installs a script path in mode2. The
scene now owns that private predicted path, rates and animation; NetworkWorld
continues importing the server's canonical state unchanged. Old nonzero action
replies retain the preview as in781e80/8001f0. Matching replies and interruptions
can correct it. Click movement shares the sequence owner. Release/session/area
changes cancel pending asynchronous preview installation.

Original8114d0 updates2a8 from path direction only for ordinary paths; script
paths retain the keyboard-facing target. Preserving that target fixes unwanted
turning during backward/strafe movement and collision corrections. Turn-only
input installs an in-place preview instead of finishing the previous lookahead.
The native-facing oracle initializes2a8 explicitly; uninitialized zero-target
observations from the first exploratory run are not acceptance evidence.

Original6ea9e0 and free/partly blocked7fdeb0 run in isolation against the unchanged
89.8193.37-17 binary:90 plans and4 line-clipping cases.27 original8114d0 script
cases confirm retained facing. See native-drive-preview-v1.json and
native-network-motion-facing-v1.json. The earlier3933 waypoint/correction
observations and installed wire replay still pass. Final focused checks:92
passing; installed-resource suites:6 passing; production buildv4 passes.

Collision preview uses resolver/area-private WOK/PWK/DWK resources and existing
native polygon queries. Door bounds mutate their orientation argument, so the
adapter supplies a private copy. Collision-only parsing skips independent dummy
action nodes, including custom indices outside the six native use slots, while
the default action-point parser remains strict. This repairs the error that
prevented the initial preview from running. The complete original client line
query, fully blocked wall sliding, ghosting and bump policy remain unported;
the adapter conservatively declines a preview when it cannot find a clear line.
Those limitations prevent claiming complete movement parity.

The user now restricts all testing to the local server. The Arelith test client
was closed before local testing. New harness probe-local-keyboard-presentation
rejects every endpoint except127.0.0.1:5121 and reads the installed wizard BIC
without copying it into the workspace. Credentials remain in one-use encrypted
memory input. It records controlled poses and movement-message headers only,
with no chat, authentication bodies or raw packets. The final local Prelude
run and derived proof supersede the remote packet-only smoothness claim.

The overall multiplayer goal remains incomplete.

## Native contact fallback and resend timer, 2026-10-20

The previous local graphics keyboard run failed strict free-motion acceptance:
Q stopped at10.07/5.69 while held. The server also became idle there. That
finding was preserved rather than reclassified as a pass. This follow-up found
three missing behaviors in the client presentation path.

Original7fdeb0 mode2 first tests the direct line and six decreasing-step
bisection candidates. If no forward fraction clears, it searches two angular
brackets for up to15 iterations. It chooses the direction using the original
dot-product comparison, applies at least0.25 speed/distance factor, and verifies
the final endpoint before installing a two-point script path. Candidate targets
use displayed position38; the path origin remains predicted position2c0.
The port now preserves that distinction, scalar factor and existing script
facing. It uses the already reconstructed normalize230920, including its
near-unit tolerance and reciprocal-root float arithmetic.

Original7fe3dd calls6f1bc0 after a partial direct path. This adjusts UI1a0 to
now-(500000-trunc(floatRatio*500000.0)) microseconds. The ratio is the final
bisection fraction, separately captured at XMM1; it is not the script speed
factor. Consequently the next wire/input refresh can occur before250ms.
NetworkKeyboardInput now handles that earlier tick and ignores a late geometry
result after input release, replacement or area/session ownership change.
The ordinary free-space250ms local/500ms wire cadence remains unchanged.

Original6ea9e0 requests764300's held-key animation even when7fdeb0 installs no
path. The scene now handles that cue independently of successful path install.
It also synchronizes the binding's idle base when a short path ends and checks
the combat owner's actual base on restart. Previously its stale walking cache
could leave the model playing idle after motion resumed. Canonical object state,
network authority and server collision decisions are untouched.

Read-only native validation on unchanged89.8193.37-17/SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a:

- 118 mode2 installer cases, including distinct displayed/predicted origins,
  match3491 ordered collision-query inputs/results, final admission, endpoint
  and speed factor. Six partial-line cases match endpoint, speed and timer
  ratio. Eight complete6ea9e0→7fdeb0 rejected-path cases confirm the animation
  request still occurs. Lower abstract collision predicates/area lookups and
  allocators are explicitly captured; this does not prove full world collision.
- 11 original6f1bc0 executions match the stored timestamp with a captured fixed
  native timer. Sources inspect-native-drive-slide.py and
  inspect-native-drive-refresh.py; derived native-drive-slide-v1.json and
  native-drive-refresh-v1.json. The existing isolated instruction harness maps
  the installed binary read-only.
- 53 focused drive/input/session checks pass. A38-test installed movement/scene
  run also passes, including the3933 native movement observations.
  Production builddrive-slide-v3 passes.

Local-only acceptance: live-v2, PID45172, ordinary installed wizard on unchanged
Prelude server127.0.0.1:5121. Standard six-key check passes386 translational
frames with zero stationary translation steps; A/D turn in place. Actual active
paths retain their movement clips. The separate contact scenario walks through
the normal server path to10.40/4.87, requests the recorded orientation through
normal6/28, then holds Q/E through production renderer input. It exercises eight
partial timer adjustments and five scaled slide paths. Facing remains unchanged,
movement resumes without a stale idle clip, and settled render/server positions
agree within0.05 units. No renderer/movement diagnostics or failed scene objects.
Derived verifiers: verify-local-keyboard.cjs and verify-local-drive-contact.mjs;
proofs creation-performance-drive-slide-free-proof-v1.json and
creation-performance-drive-contact-proof-v1.json. No DM/teleport/gameplay bypass,
remote connection, game assets or authentication bodies in the saved evidence.

Residual contact pauses remain explicit: Q has five short pauses, largest28.2ms;
E has one16.4ms pause. Those frames play idle between very short partial paths.
This is improved native fallback/timing coverage, not flawless movement acceptance.
Client line7e6a20 and creature circle query767740 still differ from the current
shared server-direct-line/conservative creature adapter. Native client767740
has its own DM/control bypass, radii and segment/endpoint tests; reusing the
server visibility/death/bump rules would not establish parity. That boundary,
dense-world performance and prolonged/fullscreen acceptance remain open.
