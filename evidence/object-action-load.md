# Saved action queue restoration

Target: read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Continues `game-effect-load.md` and the generic state saver.

`object_action_load.js` ports the whole LoadActionQueue1404963f0..1404969a2
coordinator. Its12 temporary parameter slots are initialized and populated in
serialized count order, then passed through existing AddAction48cb80..48cecc
and AddActionNodeParameter48d2c0..48d3e1 semantics. Restoring a queue appends;
it does not clear existing nodes, directly copy parameter counts or overwrite
group counters. Group65535 allocates/increments/skips65535, group65534 resolves
the prior allocated group, and AddAction stops at the first type0. Parameters
after a type0 are still read before that AddAction call. Unknown nonzero types
retain Type with zero data, matching initialized native node storage.

Types1/2/3 preserve low32 signed/raw float bits, type6 is BYTE, type4 owns a
copied encoded string, type5 transfers an actual VM situation owner. The
literal nested list label is `Paramaters`. Missing typed fields use native
defaults. A failed nested list/element/VM-struct read retains the previous
native local, including across actions; the port retains the corresponding
owned value. A first uninitialized failed read and count>12 diagnose unavailable
native/corrupt state rather than inventing a value or reproducing stack writes.

The original heap temporaries/free branches do not create additional gameplay
IDs or queue nodes. JS scalar/string temporaries are managed values; node
string copies and VM ownership transfer still follow actual AddAction behavior.
Native type6's temporary has no matching cleanup branch; no observable engine
behavior is inferred from that omission. General allocation failure/native
memory corruption is outside validation.

`ObjectStateRuntime.load` now binds the real action loader. INT and FLOAT were
added to the shared typed GFF adapter, with actual widths and binary32 rounding.
VM type5 parsing dispatch is present in the pure owner; the live VM serialization
and restoration owners remain unavailable and explicitly diagnosed. This is
not a placeholder executable script or a claim that arbitrary saved scripts
can yet run. No new engine-command binding or hardcoded spell was added.

## Verification

- `inspect-native-object-action-load.py` executes all three unchanged original
  bodies above.79 cases compare complete appended nodes, parameter data/counts,
  interruptibility, next/last group fields and VM load dispatch. Includes all
  primitive types, owned embedded-NUL strings, high object IDs, raw negative
  zero, unknown/zero types, group wrap, repeated/retained list handles, VM
  struct retention,60 randomized cases and two seeded-queue append cases.
  GFF, successful heap/list storage, string assignment and opaque VM loading
  are explicit captured boundaries. VM marker fixtures prove dispatch only.
  Logs native-object-action-load-v1/v2; final observations JSON retained.
- `object-action-load-focused-v3.txt`:26 targeted tests pass, covering original
  comparisons, malformed state diagnostics, item wrapper/runtime, generic
  state load/save, saved effects and action management. Build-v1 passes.
- `installed-item-save-v10.json`:installed Prelude/wizard/item, saved queue
  appended through generic object-state loading to an existing canonical item
  with an existing node. Existing node identity survives; imported target ID and
  raw FLOAT bits are exact; complete item re-save emits both actions. No object
  or effect identity allocation occurs. The previous temporary-property full
  save/load/strict-expiry cycle still passes. All diagnostics retained; deliberate
  unsupported VM-save records and existing resource/presentation warnings remain.
- Installed-v9 exposed missing INT/FLOAT reader kinds in the live GFF adapter;
  those real typed cases were added, then v10 passed. No admission gate was
  bypassed and no full~2000-test suite was run for this change.

## Next

Complete VM script-situation serialization/restoration and capture metadata,
including actual code buffers, PCs, stack sizes/capacity, engine structures,
JmpList ordering and event/chunk ownership. Complete analyses now retained for
LoadScriptSituation_Internal282ab0..283229, RunScriptSituation284830,
CVirtualMachineScript constructor27db60, stack load search/result and body,
and capture/copy searches. These are research, not completed owners. The current
VM has logical cells/PC/BP but does not retain all native save metadata; no zero
capacity/debug/jump values should be invented to make serialization pass.
Then finish opaque solver/JSON locals, creature save/load and CopyObject's
lifecycle, alongside the remaining spell/combat/campaign goal. Goal ACTIVE.
Captured stack/code metadata has since advanced; see
[native VM capture](vm-situation-capture.md). Full VM save/load remains open.

Checkpoint `backups/object-action-load-20261017-v1.zip` sealed successfully;
writer26484 terminal0 consumed. Exact archive counts/bytes are in
`object-action-load-checkpoint-v1.txt`; every archived length/SHA256 verified.
This verification note was added after sealing.
