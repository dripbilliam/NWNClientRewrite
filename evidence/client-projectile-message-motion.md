# Client projectile header and motion — 2026-10-16

Progress toward the active spellcasting/combat/campaign goal. No spell-specific
gameplay exception was added. Header decoding is connected to local delivery;
the tested motion functions await path/model integration. Visible projectile
rendering, native client cast/release messages and campaign parity remain open.

Read-only target: NWN:EE89.8193.37-17, x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original Ghidra project and installation unchanged. REA uses its isolated import;
Capstone/Unicorn execute original instructions against owned synthetic state.

## Evidence and implemented behavior

- Native sender4df550..4df784 writes two
  OBJECTIDs, six FLOAT(scale1,bits32), DWORD duration and BYTE appearance. For
  appearance6 it writes DWORD spell ID;7 adds a path BYTE. Other appearances
  write path, base item and result BYTEs, in that order. Appearance>7 uses native
  client build admission and may downgrade to0. The local projector matches the
  selected native sender layout; it is not a replacement for build negotiation.
- Server object writer4763e0..476435 preserves invalid7f000000 and otherwise
  sets80000000. Client object reader9737c0..9737e7 retains these bits, returns0
  on short read and advances its DWORD cursor even on failure. No authoritative
  object ID or allocation cursor is changed by this bridge.
- Receiver7ac670..7ae8c4 is identified through its caller/object construction
  and CNWCProjectile RTTI/vtable140e72b98. The implemented bounded header is
  7ac7d1..7ac97b: three overflow guards, matching field order/defaults and
  appearance branches. Decompiler float typing for the spell field is misleading:
  assembly moves raw DWORD bits toR15D; GetSpell receives that integer.
- Motion9845c0..9848cb computes binary32 velocity from remaining milliseconds,
  endpoint delta and acceleration, advances by elapsed milliseconds and clamps
  overshoot. Spiral9848d0..984c13 adds a normalized horizontal perpendicular
  at native7.5 speed, with native side-byte selection. Both preserve the facing
  modes:0 skips orientation,1 faces the cached attachment,2 faces movement,
  other nonzero bytes use endpoint delta. Orientation only updates above native
  squared epsilon1e-10. Shared normalize230920 retains its exact rounding.

`src/client_projectile_message.js` supplies the local typed field projection,
client-ID conversion and bounded reader. `src/main.js` decodes delivered headers,
then durably records `visual.projectile-scene-unimplemented` with both canonical
and external IDs. Malformed fields record `visual.projectile-message-failed`.
`src/client_projectile_motion.js` contains the tested basic/spiral step routines;
these are not yet invoked by a live client projectile scene.

## Validation

- `native-client-projectile-message-observations.json`:774 original cases
  (504 bounded receiver headers,216 sender admissions/layouts,24 object writes,
  30 object reads); four tests pass. Scalar message operations, overflow, build
  admission, payload and transport are captured lower boundaries; the OBJECTID
  writer/reader execute unchanged. This does not execute raw packet framing,
  debug/type bits or transport bit streams. Capturev1 had a fixture variable
  shadow; finalv3 is the acceptance capture.
- `native-client-projectile-motion-observations.json`:1318 original cases,
  2026 motion steps; three tests compare binary32 position, velocity, orientation
  and callback order. Covers UINT timer extremes, zero time, overshoot, both
  spiral directions, facing modes, tiny/zero displacement and60-step trajectories.
  Imported sqrtf and final virtual position/orientation writes are captured lower
  boundaries; native normalize executes. NaN values compare by classification,
  all other results by exact float bits. No whole-AI/path or rendered-model claim.
  First capture stopped at the missing sqrtf boundary; finalv2 passes.
- Full1815 tests and production build pass (`client-projectile-full-tests-v2.txt`,
  `client-projectile-build-v2.txt`). Installed prepared wizard Daze37 emits one
  release/projectile/original impact, decodes its external IDs and preserves
  authoritative allocation (`installed-client-projectile-message-v1.json`). The
  spell name/ID chooses a probe fixture only; generic runtime logic does not.
- Built UI spellbook, self-target radial, hotbar F2, slot consumption, animations,
  cancellation and counterspell wheel regression pass (`client-projectile-ui-v1.txt`).
  `live-casting-ui.png` inspected: world/creatures/HUD present, occluding black
  geometry and existing missing `plc_w02.pwk` diagnostic remain. GPU teardown
  warning follows successful assertions. This is not an issue-free campaign run.
- REA23-tool registration and complete retained receiver paging pass independent
  verifier (`client-projectile-rea-verification-v3.txt`). Large receiver analysis
  is retained and paged without silently truncating it.

## Next native owners and limits

Constructor9832a0 registers type8 transient objects in a separate client object
array using AddInternalObject295d40, then client AI. Incoming server references
remain external-bit IDs. Do not allocate projectiles/dummies from ModuleSession's
authoritative registry or invent an unrelated identity system.

Receiver uses active spell records for spawn node, model, path and sounds. It
creates c_dummy targets when required, with duration+500 lifetime; source launch
fallback is packet position+Z1. Actual model attachments and model failure cleanup
must be retained. Spell appearance6 takes the path from data;7 uses the packet
override. Path4 spawns five projectiles in the receiver. Ranged appearances have
separate ammo/weapon rules; do not treat them as spell visuals.

REA dossiers now retain constructor9832a0, LoadModel984300, AIUpdate983860,
motion coordinator984f00, configure-path987770, initialize-node987f10 and
next-node988ed0. Path configuration has physical linked nodes and random,
attachment and multi-node branches. The frame coordinator resolves current
impact attachments, decrements countdown and dispatches tested motion. Initial
conditions, path switching, lifetime/stage2, impact/shield attachments, sound and
resource cleanup still need implementation and independent original-code tests.
Active2DA lookup must supply fields; no spell-name renderer special cases.

The separate `spell.client-message-unimplemented` diagnostic remains. Previous
auditv47 (65 unbound/22 missing) is unchanged evidence, not a new audit. Full spells,
combat and campaign acceptance are not complete.
