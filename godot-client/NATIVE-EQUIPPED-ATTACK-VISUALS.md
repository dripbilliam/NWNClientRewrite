# Native equipped-weapon attack visuals

2026-10-27. The normal native client now connects original body blur events to
equipped weapon slotFB and scoped attack colours. This is scoped integration;
live/GPU testing remains paused at the user's request while another game runs.
No server, graphical client, public connection or GPU benchmark was started.

## Original behaviour and evidence

Read-only NWN:EE89.8193.37-17, nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`scripts/inspect-native-equipped-attack-visuals.py` executes unchanged
`0x1407fd6b0..0x1407fdb0d` with controlled item/resource/model/colour boundaries.
`reports/native-equipped-attack-original-v2.json` retains952 cases, instruction
and script hashes. It proves the state transitions and ordered calls, not the
complete original renderer, outer callers or server combat outcomes.

- Matching enabled state returns immediately. A nonzero opaque item+2a8 BYTE
  returns without committing. Static disassembly at83c5d4 shows constructor
 83c480 initializes this BYTE to0; no invented semantic name is assigned.
- Equipped `ModelType2` uses **ItemClass + `_mb`**, probes original MDL type2002,
  loads slot251/FB, and configures that slot with arguments0/0. Missing resources
  or failed loads leave enabled state uncommitted. Other model types commit
  without loading an effect. Native base-item loader29dfa0 stores ModelType at
  row+16 and copies ItemClass into row+40 with a ten-byte bound. The retained
  loader evidence is `../backups/animations/rea-base-item-loader-retained-rest.json`.
- Start colour maps raw attack WORD6 to red;17/23 to green;9/16 to blue;31 to
  [1,0.2,1];65000/65001 to[0.2,1,1];301 to[0,0.5,0.5]. Other WORDs leave colour
  unchanged. No unverified feat names are assigned to these numeric fields.
- End removes FB, clears colour scope4 and resets local attack type. These are
  presentation changes, not feat/spell requests or authoritative combat state.

`scripts/inspect-native-model-colour-scopes.py` separately executes original
set965cf0, clear968590 and composer966170..966406. Its1024 retained cases in
`reports/native-model-colour-original-v1.json` show lowest-active-scope selection
over scopes0..4, including invalid BYTE scopes, absent models and clear/restore.
It captures raw virtual method180 RGB and method178 RGB/alpha calls. Complete
shader internals are not emulated; optional renderer registration is disabled
through the original global flag, as recorded in the report.

## Native ownership

`creature_stream.gd` carries active base-item metadata into admitted held models;
the client embeds no stock weapon list or rule table. `equipped_attack_world.gd`
uses the same original weapon-start/end events as unarmed specials, with private
models under `effect_world.gd`. It warms original resources without withholding
control. Ready models load synchronously in the blur callback. A pending native
load can finish only while its original attack window is still wanted; a later
blur-end discards that pending presentation rather than showing a stale swing.

The model follows the actual held root, including current position, rotation
and scale. Canonical lifetime, installed appearance, held-item identity and actor
binding guard it. Removal/replacement and world closure release the model and
listener. The signal callback's own dictionary binding is explicitly erased to
avoid a Callable/record cycle. No effect model is added to server object identity.

`model_colour_scopes.gd` reproduces priority selection. Native Part poses apply
selected RGB through private Godot material albedo/emission bindings, preserving
controller alpha and restoring underlying material/controller values on clear.
This is the Godot rendering adaptation, not proof of exact original shader
semantics. Held-model admission preserves its current clock/serial and suppresses
replayed admission events. Higher-priority scope changes propagate to the
attached blur too. Another actor and shared original resource materials remain
untinted. Original models/textures and server outcomes are unchanged.

## Verification and queued acceptance

Current headless debugger reports, with unchanged sources and clean console,
engine, exception and lifecycle results:

| Report prefix | Checks | Scope |
|---|---:|---|
| native-equipped-final-data-v1 | 954 |952 original attack transition cases and resource bounds |
| native-equipped-final-colour-v1 |1025 |1024 original colour state/composer cases |
| native-equipped-final-world-v1 |22 | Actual original actor, weapon pieces and wswss_mb; active metadata, private materials, clock, attachment scale, priority, duplicate starts, delayed expiry, replacement and teardown |
| native-equipped-final-special-data-v1 |938 | Retained original unarmed gate/load/play regressions |
| native-equipped-final-special-world-v1 |21 | Actual original unarmed model/Part/lifetime regression |
| native-equipped-final-cast-controller-v1 |4069 | Original casting controller fields and ordered boundaries |
| native-equipped-final-cast-world-v1 |28 | Native casting models, attachments and lifetime regression |
| native-equipped-final-ui-v1 |1025 | Existing native text/dialog/examine/UI regression |

The live actions probe now includes equipped-model anchor, viewport pixel
difference and blur-end retirement checks in the existing owned-server parry
scenario. **Prepared, not run** while live/GPU testing is paused:

```powershell
./godot-client/tools/test-native-actions.ps1 -Parry -Run native-equipped-parry-live-v1
```

Still required: that actual original-server check, visual review of ordinary and
coloured swings, wider weapon/custom-row/shape coverage, native shader and outer
clock acceptance, and paired-client gameplay. Original810680 initialization and
8033c0 level20 aura remain separate work. Earlier intermittent Stunning Fist and
chained special-feat issues are not declared fixed by this integration.

## Superseded evidence and checkpoint

The initial integration mistakenly used DefaultModel rather than ItemClass;
`native-equipped-attack-world-v1` exits before model acceptance. The original
base-item loader and active asset lookup corrected the binding. Original owner
corpusv1's mislabeled input is superseded byv2.

`native-equipped-attack-world-v2` passes its22 assertions but printed five leaked
ObjectDB instances and one resource on stderr. Its old wrapper missed that stream;
it is **not** clean lifecycle acceptance. The record/listener cycle is corrected,
and the debugger wrapper now saves `.console.log`, captures stderr, and rejects
leak/resource/Unicode warnings. Current final reports use that corrected wrapper.
The earlier data-v1 NUL-string warning is superseded by the corrected native
string handling and final data check. Failed evidence remains retained.

Verified source backup: `backups/native-equipped-attack-visuals-v1.zip` with
read-back manifest. Acceptance/source-hash ledger:
`reports/native-equipped-attack-audit-v1.json`. Full gameplay, visual parity,
mixed-client and performance acceptance remain false.
