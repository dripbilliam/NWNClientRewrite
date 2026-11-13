# Native SessionWorld reset regression

`tests/native_session_reset_test.gd` **extends the actual SessionWorld SceneTree**.
Its `_initialize` only defers its own test method. It does not instantiate a
second SceneTree, call the base `run`, read a ticket/profile, connect the peer,
mount resources, configure native clocks or start a visible renderer.

The fixture constructs one Label and inert catalogs. A temporary empty Node3D
exercises the live pointer policy, then is freed before any reset/retirement.
The15 checks cover partial raw assembler/base/caption reset, preservation of the
Host-global serial, repeated reset, existing queue/epoch resets, pointer queries
without mutation, actual retired/cancelled-connection raw admission and a later
higher-serial full-frame beginning. Incoming dictionaries are authored protocol
inputs, not original-server captures. No snapshot end triggers world creation.

Root owns the production correction: move `raw_world={}`,
`accepted_raw_serial=-1` and the default label assignment from after the pointer
handler's unconditional return to the end of `reset_session`. `raw_serial` is
intentionally preserved. This test does not change that producer.

```powershell
node godot-client/tools/test-native-session-reset.mjs native-session-reset-v1
```

The dedicated runner copies the current static dependency closure, feedback
descriptors and existing particle descriptor/library into a private project.
It uses the pinned existing engine, headless, with owned temporary application
data and a65s cap. It verifies source/copy hashes, engine/Node identity, six main
native outputs and main project/extension-list hashes. It writes only new
evidence/project files under `.cache/native-session-reset/<fresh label>`.
No compiler/build, server, GPU, original process or shared installation is used.
Windows certificate-store access may require the already approved escalation;
warnings/errors and failed labels remain failures.

Acceptance is this isolated reset/control-boundary regression. It does not
establish a new original-server reconnect result or explain the historical
Cleric IPC close.
