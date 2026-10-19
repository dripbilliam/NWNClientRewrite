# Engine values in saved VM snapshots

Target: read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Continues `vm-snapshot-serialization.md`; full spell/combat/campaign goal ACTIVE.

`script_engine_structures.js` ports virtual SaveGameDefinedStructure
140552d60..140552e66, LoadGameDefinedStructure5521d0..552435 and
CreateGameDefinedStructure50d170..50d25c. The nested GFF label is literally
`GameDefinedStrct`, whose struct type is the engine kind. Unknown save kinds
still write this header and return0; unknown load kinds leave the output pointer
unchanged and return0. SQL/solver/JSON save virtual28 results are ignored and
the wrapper returns0; their load virtual30 result is ignored and wrapper
returns1. Those virtual payloads remain explicit live missing owners.

Effect/itemproperty engine load uses the actual constructor(1), consuming a
uint64 effect ID before the loaded saved ID replaces it. The live bridge uses
the real effect allocator and previously verified LoadGameEffect/SetCreator.
This differs intentionally from object-effect import's constructor(0). Saved
property/link IDs remain omitted as in the original. Location reuses actual
stored-coordinate save/load owners, with no resolution or normalization.

Full Event Save4c7070..4c728b and Load4c6ba0..4c7067, and Talent
Save49a570..49a638/Load497880..49798a are now ported and native-checked. Events
append each typed parameter list when loading, retaining/growing actual array
capacities (initial16/doubling). Save emits only nonempty lists, struct105 and
Parameter fields. Talent loads all seven fields with zero read defaults. Its
long literal ItemPropertyIndex uses the native16-byte GFF-label truncation.

Event constructor4c6490 leaves its type WORD unwritten; host storage marks it
undefined rather than inventing0. EventUserDefined51d510 sets WORD11 and INT
slot0; the client command now returns this canonical structure. SpellCastAt's
type2 event now also carries all constructor-owned empty arrays/capacities.
SignalEvent accepts native type11 while retaining compatibility for manually
supplied legacy host events. Its existing script dispatch timing was not
redesigned in this change. GetInteger4c6af0 confirms missing slot0 returns0.

Fresh event copying differs from loading: CopyScriptEvent4c68d0..4c6acf uses
exact source counts for fresh destination capacities. Its integer SetSize
04c720 and string Allocate0f5140 bodies were inspected; no spare source capacity
is inherited. `copyScriptEventValue` now supplies this behavior in VM event
push/copy/capture/resume paths, replacing generic structuredClone for events.
This was found and fixed after the first installed round trip, even though
capacity is not serialized and that earlier test already passed.

VM RSADD now uses the native known constructors: effect/itemproperty ctor0
(no ID), event with unwritten type, zero-vector/invalid-area location, talent
constructor; other Create kinds return native NULL. The location zero constant
now uses its actual stored default location, matching ExecuteCode's local
zero-vector/invalid-area structure. Opaque wrapper push/copy/lifetime remains
unfinished; no full VM ownership claim is made for those types.

`ScriptEngineRuntime` connects effect, event, location, talent and itemproperty
save/load to `ScriptSituationRuntime`. No spell-specific path, module name,
game-object allocation or authored-state fallback is introduced.

## Evidence

- `inspect-native-script-engine-structures.py` finalv4:58 cases execute unchanged
  save/load/create wrappers, actual effect constructors, effect/event/location/
  talent save/load payload bodies and event copying/integer SetSize. Compare
  typed GFF, complete loaded payloads, constructor defaults, event append/copy
  capacities, lower return policy and actual native global effect-ID counter.
  Seeds include2000000000000001 andffffffffffffffff; constructor increment and
  wrap are tested without Number conversion. Successful GFF/heap/string/array
  storage, SetCreator and opaque SQL/solver/JSON virtuals are captured boundaries.
  Array/string allocation boundaries were additionally inspected; no general
  allocator/refcount or allocation-failure parity claim.
- Native observation seed values are hex strings, preventing JS precision loss.
  V1 was replaced before JS comparison because raw JSON integer seeds above
  2^53 were unsafe; v2 fixed that representation. V3 adds original constructors;
  v4 adds native event copies after their distinct capacity rule was discovered.
- `script-engine-structures-focused-v5.txt`:66 focused tests pass, including
  old VM format/capture/action behavior, native engine payloads, live allocator
  wrap/full-ID restoration, event notification/location/talent/item/feat calls
  and diagnostics. Build script-engine-structures-build-v1 PASS. No full suite.
- `installed-vm-engine-values-v2.json`:actual installed Prelude/wizard/active API
  with an explicit NCS fixture. NCS engine calls produce EventUserDefined321,
  Location at canonical area1, talent, item-property enhancement and haste.
  Actual STORE_STATE captures five engine cells from original SP7/capacity21.
  Generic object-state saving, actual cancellation/disposal and reload preserve
  all payloads and saved effect IDs...88/...89. Exactly two load constructor IDs
  are consumed, matching native behavior. Re-saving is GFF-equal. The real
  DoCommand runner resumes ApplyEffectToObject using the restored haste value,
  then its expiry/removal succeeds. Registry IDs/allocator cursors are unchanged;
  no error-severity diagnostics were recorded. Existing warnings retained.
  Startup/general AI isolated; not a campaign or shipped-spell completion claim.

## Next

Finish SQL/query, Cassowary and JSON virtual serialization/shared ownership,
native jump-map insert/rehash/copy order and remaining script lifetime paths.
Current snapshots explicitly diagnose those live missing owners. Event type11
is now canonical, but full SignalEvent/AI-event parity beyond its existing
routes remains a separate subsystem. Full creature/CopyObject lifecycle,
remaining spell interactions/combat and base-campaign play/fix loop remain open.

Verified checkpoint `backups/vm-engine-structures-20261017-v1.zip`:
11561 files/175328699 bytes; every archived length and SHA256 verified.
Writer35862 terminal0 consumed, log `vm-engine-structures-checkpoint-v1.txt`.
This verification note and seed-text clarification were added after sealing;
the native observation seed and tests already used the correct full-width value.
