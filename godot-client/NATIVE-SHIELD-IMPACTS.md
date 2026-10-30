# Native shield-block ammunition

Actual original-server shield blocks now embed the original arrow in a physical
held-shield impact Part. This is scoped combat progress toward
[base-game parity](BASE-GAMEPLAY-GOAL.md); full combat, mixed-client acceptance and
the migration goal remain incomplete. Native Godot reads active server resources,
owns the model and advances its attachment. No JS asset preparation or rendering
is involved, and the client does not decide whether an attack is blocked.

## Correct original field

Read-only research targets NWN:EE 89.8193.37-17, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
In original projectile AI `0x140983860`, instruction `0x140983ed4` compares
`byte ptr [RAX + 8]` with 7 after equipment-slot32 lookup. The relevant slice of
`CNWBaseItemArray::Load` at `0x14029dfa0` writes **WeaponWield to byte8** and
**WeaponType to byte9**. The receipt, retained evidence IDs, literal column bytes
and coverage are in `reports/native-shield-field-mapping-v1.json`. Only the
relevant first26,000 of57,725 pseudocode characters were inspected; this is not
acceptance of the complete table loader.

The earlier native adapter incorrectly queried WeaponType. Stock shields have
WeaponType0 and WeaponWield7, so pure impact tests passed while real shield
admission failed. The production provider now queries the active `baseitems`
WeaponWield column, retaining the original unsigned-byte conversion. It does
not hard-code base-item rows or model names. The original stored impact corpus
remains immutable: its historical `weaponType` JSON key is the raw byte8 value,
explicitly translated to the corrected native provider name `weaponWield`.

## Actual native attachment and lifetime

The existing ranged impact owner resolves the actual held item's original
`imp_shield_1`/`imp_shield_2` Parts, preserving the original selection and
attachment flags0. Shield blocks stay distinct from damaging body-hit tracking
and blood. The original8000ms countdown releases the private model. Canonical
target lifetime checks prevent queued/live work from binding to a reused server
identity; world close releases pending headers, private IDs and model owners.

The first real attachment also exposed a one-frame lag: a sampled arrow was
0.031m from its moving shield Part. `native_render/effect_model.gd` now updates
attachments at process priority10, after actor rigs publish physical poses at0
and before particle simulation at20. Real small/large/tower block captures now
measure zero position difference. This is a Godot scheduling correction; full
original outer scene ordering and paused-clock parity have not been established.

## Validation and retained failures

The authored localhost fixture uses the unchanged original nwserver, installed
ranger equipment and ordinary CreateItemOnObject/ActionEquipItem/ActionAttack
script calls. Shield proficiency32 comes from the installed script API. The
server resolves the actual shot/result and consumes real ammunition. Small,
large and tower variants use installed blueprints `nw_ashsw001`, `nw_ashlw001`
and `nw_ashto001`; these names/rows belong to the test fixture only.

Evidence under `reports/`:

- `native-shield-impact-oracle-v1`:2604 stored original impact/provider and finite
  orientation checks. The original corpus identities are unchanged.
- `native-shield-lifetime-v2`:15 actual original actor/shield/arrow component
  checks: active table fields, both physical Parts, pose following, expiry,
  deferred/live canonical reuse and complete owner cleanup. Authored block
  fields in this component test do not prove server outcomes.
- `native-shield-shutdown-v1`:26 real small-shield checks with11 embedded-arrow
  viewport pixels, actual result2, zero follow distance, model expiry, unchanged
  source pins, normal-heap exception capture and zero remaining workers.
- `native-shield-large-v1` and `native-shield-tower-v1`:26 real checks each,
  respectively7 and15 embedded-arrow pixels, zero follow distance and clean
  original-server/native cleanup. Their earlier source pins predate the later
  shutdown-only diagnostic; no attachment implementation changed afterward.
- `native-shield-cast-owner-regression-v1`:28 actual casting-model owner checks;
  `native-shield-blood-owner-regression-v1`:21 actual blood-model owner checks.
- `native-shield-casting-regression-v2`:39 real original-server effect/area,
  beam/Fireball/Magic Missile, Detonate and cleanup checks.
- `native-shield-bow-regression-v1`:24 real server bow/body-hit blood,
  ammunition/flight and cleanup checks; `native-shield-parry-regression-v1`:
  15 real server melee/spark checks.
- `native-shield-gameplay-regression-v1`:65 actual menu/gameplay checks;
  `native-shield-prelude-regression-v1`:two original Prelude cycles, one
  interrupted streaming load and a pending-connect cancel followed by reconnect.
  Cancellation closed the local peer in3.002ms in this functional run. This is
  not a general latency/performance claim. All these accepted runs exit0 with
  unchanged source pins, armed native exception capture and zero worker residue.

`tools/audit-native-shield.mjs` verifies relevant current-source pins, original
corpus identities, binary field receipt, actual three-shield outcomes/pixels,
regressions, failed shutdown evidence and the verified source checkpoint. Its
scoped result is `reports/native-shield-final-audit-v1.json`; goalComplete,
fullCombatParity, mixedClientAccepted and performanceAccepted remain false.
Before checkpoint: `backups/native-parry-visuals-direct-after-v1.zip`,
SHA256`f427a6dc1e43b6c3c5368cfd27aa1770b7de3a5198cb4ca273a22921df6c60f5`.
After checkpoint: `backups/native-shield-impacts-direct-after-v1.zip`; its verified
read-back manifest records archive/per-file hashes. Original art/executables
remain external.

The fixture-only v1 attempt confused large-shield row56 with small-shield row14
and failed before launch. Live v2 exposed the wrong field; v3 exposed attachment
lag. Component lifetime v1 requested nonexistent `ashsw_001`; the original small
shield blueprint actually selects part11, `ashsw_011`. These failures remain
retained rather than overwritten.

`native-shield-final-v1` passed its26 assertions and character export, but timed
out during native shutdown without a final native report. It is a **failed run**,
not accepted cleanup evidence. A repeat with shutdown-stage diagnostics completed
all boundaries and exited cleanly. `*.native.shutdown.json` now records each
shutdown boundary using shutdown-only I/O; the exact intermittent stall remains
unresolved until it can be captured or otherwise established. No claim that
instrumentation fixes that failure is made.

Particles retain the user's default-off setting; these isolated visual tests
explicitly enable them. Known unrelated emitter wind diagnostics and black
terrain wedges remain. Background functional captures do not establish FPS.
Shield unequip/physical-host removal semantics, full original attachment/clock
ordering, weapon effects, reactions/death/audio, broad custom resources and
paired-client gameplay remain open. No automated public server connection was
made.
