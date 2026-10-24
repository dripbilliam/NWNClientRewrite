# Native repeated-key refresh, 2026-10-20

Production NetworkKeyboardInput now consumes each admitted movement key-down
as an input refresh, including repeated events for an already-held key. The
periodic250ms local-preview/500ms wire timers remain the no-event fallback.
The previous handler only compared aggregate direction flags, so an otherwise
identical repeated key-down could not bring the next refresh forward. The
existing packet codec, movement sequence owner, server authority, collision
queries, slide solver, speeds and canonical objects are unchanged.

Pinned original89.8193.37-17 x64 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Read-only static findings and isolated execution:

- WinMessageHandler45490 passes SDL events to CExoInput::AddEvent16e830.
  Internal16f880 admits normal and repeated SDL_KEYDOWN events; the repeat
  byte is not used to reject them. Its a6f930 helper copies GUI events rather
  than filtering keyboard repeats. Typed16fc30 enqueues the resulting event.
- GetEvents1700a0 maps queued records through active input descriptors.
  GUI6ed720 writes the held direction and input-dirty1b0 even when the held
  value is already1. For the selected strafe-left descriptor, case28 at
 6ef23a also refreshes the local input timer.6f1e40 treats dirty input as an
  immediate send/preview; it publishes2d3 after the local preview call.
- inspect-native-drive-input-timing.py executes192 complete6f1e40 scheduling
  cases: changed/periodic, sub-threshold/exact250ms and500ms boundaries,
  four direction combinations and sequence36/255. The replacement agrees on
  preview/send decisions, timer values and sequence advancement. Captured
  timer, object/model lookup, preview/send and heading transcendental lowers
  are declared; the original control/arithmetic instructions execute.
- Two additional cases execute original16f880 and6ed720 on normal/repeated
  key-downs for an already-held direction, followed by6f1e40. Both queue the
  press, mark dirty1 and immediately send/preview, advancing36 to37. The
  descriptor binding and queue insertion lower are synthetic/captured; this
  is not a full native OS/event-pump trace. The initial expanded replay
  failed because its16f880 execution allowlist ended before the final native
  instruction. The exact inspected range fixed that harness error; the
  failed-v2 log is retained and successful-v3 executes the intended slices.

Metadata: native-drive-input-timing-v1.json. Read-only dossiers use
rea-drive-client-platform-*.json; existing events/UI pseudocode and assembly
are also retained.22 focused native-timing, keyboard, preview and slide checks
pass. Production build key-repeat-build-v1 succeeds (index-CLdrEWnW.js).

Local client48208 runs only against the unchanged owned Prelude server at
127.0.0.1:5121, PID20964. The bounded QA stream emits an initial key-down,
then repeated key-down events after500ms at approximately33ms intervals,
through the ordinary renderer listener. It is a modeled event stream, not
physical keyboard input. Six-key free motion passes382 translation frames
without stationary steps; A/D turn in place. Q/E contact executes11 partial
refreshes and20 slide paths, with stable facing and matching final canonical
and displayed positions. Q has one9.5ms pause and three held idle frames;
E has zero pauses/held idle frames. No failed models or renderer/movement
errors. Sampled settled local rendering is approximately119FPS.

The earlier no-repeat live-v4 had82.5/99.4ms contact pauses. That run used a
different input stream, so do not present their ratio as a controlled same-
input before/after benchmark. The regression itself is independently proven
by the original admitted repeated-event cases. The contact checker still
reports continuousHeldAnimation=false because three held idle frames remain.
No perfectly smooth/all-obstacle or full-path-merge/control-bypass claim.

Proofs: creation-performance-key-repeat-free-proof-v1.json and
creation-performance-key-repeat-contact-proof-v1.json. The full active live
capture remains outside the checkpoint. Scripted movement has finished; the
client remains open locally for the requested physical-key user check.

Computer Use was resumed with the authorized skill. The research installation
crashed on startup both as a bare-path launch and from its install root. The
complete Steam installation has the same pinned executable hash and also
crashed before connecting when launched with explicit127.0.0.1:5121. All
three error dialogs/processes closed; no native binary/profile changes or
crash submissions. Bounded startup-error metadata is retained, without raw
configuration or credential data. No live vanilla physical-key comparison
was obtained and the startup crash cause is unproven. The goal remains ACTIVE.
