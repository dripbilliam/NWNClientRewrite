# Camera rate setters and input flags — 2026-10-18

Read-only target: installed nwmain89.8193.37-17, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original executables and the original-client session were not changed.

## Original behavior

Input update6e6220 calls yaw7cfe60, pitch7cfdb0, and zoom7d4340.
Received16/12 stores the signed flag word. Bits16,32,64 respectively reject
new yaw, pitch, and zoom setter calls. They do not erase values previously
queued in Follow. The setters add to existing Follow values rather than
replace them. Nonzero accepted input marks manual interaction; yaw and zoom
also set their separate event fields.

Prediction storage is independent of the actual Follow accumulators. The
setters copy yaw/pitch rates to module14c/148 and zoom to158. Both angular
impulse setters write module150; yaw does not write154, although prediction
reads154 for its yaw impulse. This alias is present in the instructions and
in executed original code; the port preserves it. Full-frame lifetime/reset
of prediction fields is not proven by the individual setter oracle.

Zero keyboard/angular rates are submitted by the normal input frame. External
zoom is submitted after mode steering/collision. A wheel event by itself must
not set the manual latch before that ordering point.

Flag4 is not a chase-steering disable bit. Updater7d0470 uses it to suppress
offset effects, with50ms/.25 and70ms/.1 timing/amplitudes. Flag8 gates position
translation7cf4f0. These remaining behaviors are research findings, not an
implemented effect/translation pipeline. The bounded camera-region writer
searches are not exhaustive activation/caller coverage. The exploratory
rea-camera-effect-trigger lookup resolved to containing7cffc0, not a new
function at the requested interior address7d0000.

## Implementation and checks

camera_rate_input.js is shared by manual input, keyboard controls, native mode
steering and scripted locations. Separate prediction inputs feed clear-view
and collision prediction. Flag storage retains all bits; unsupported behavior
bits continue to produce network.camera-flags-partial diagnostics.

inspect-native-camera-rate-flags.py executes the complete three original
setters with synthetic Follow accessors as the lower boundary.403 cases/
455 setter calls compare raw Follow values, prediction fields, flags and
manual/event fields exactly.127 focused tests pass; the build passes with
the existing bundle-size warning. The Electron fixture passes107 commands,
105 location packets/116 frames, attachment/clear-view and rendered collision
in all three modes, with canonical state unchanged and empty stderr.

User-authorized reconnect closed only interactive replacement v76 normally.
Latest built replacement v77 PID44844 joined the existing unmodified Prelude
server20964. Passive snapshot network-native-camera-live-snapshot-v77.json
confirms the rendered controlled player, attached camera, completed entry
clear-view, loaded/enabled keyholing and no sample failure. The initial runtime
check recorded63 entries and zero error-severity entries. No automated input
was queued. This is readiness evidence, not an original-client visual parity
acceptance test. Leave v77 open for the user; exclude its changing live JSON,
control file and stdout/stderr from checkpoints.

Configuration persistence, shake/bump activation/presentation, translation,
other flags, SP entry/VM adapters, attachment keyholing, exact BSP/hierarchy
queries and actual concurrent original-client visual comparisons remain open.
The complete multiplayer gameplay objective remains active.

Sealed multiplayer-native-camera-rate-flags-20261018-v1.zip:13778 files/309691684 bytes. Writer75143 finished exit0 and verified every entry length/SHA256. Scope audit13779 entries including manifest, six selected required files present, zero forbidden entries. Credential-shape audit13628 text entries: four candidates, all identical to the previous safe checkpoint, zero new candidates. User confirms: “Clipping is perfect.” This records clipping acceptance for this test, not full camera or multiplayer acceptance. Post-seal note is outside the archive.
