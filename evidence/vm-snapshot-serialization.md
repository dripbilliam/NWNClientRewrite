# Native VM snapshot format and queued-script restoration

Target: NWN:EE89.8193.37-17 x64, original read-only `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Continues `vm-situation-capture.md`; this is not complete engine-value support.

## Implemented owners

`script_situation_save.js` ports whole SaveScriptSituation_Internal
140284d00..1402851c2. Writes code/optional NDB blobs, native instruction and
secondary pointers, name/original stack size, typed stack/capacity, physical
jump-list fields, chunk and event ID. Stack types are CHAR, object values DWORD,
and primitive/engine dispatch is exact. The engine return value does not stop
later writes. ASM284f35..284f45 passes the current element as the fifth engine
save argument; the decompiler omitted it. Jump labels save as C-strings, while
ordinary CExoString fields retain embedded-NUL lengths.

`script_situation_load.js` ports whole LoadScriptSituation_Internal
282ab0..283229 and LoadStack283230..2835fa coordination. CodeSize0 leaves the
out pointer untouched. Positive CodeSize reads the requested prefix of the
VOID blob. Missing/short blobs leave native bytes unwritten, so those unsupported
states are diagnosed rather than filled with invented zeros. NDB is loaded
only when its size is positive. Stack typed fields/defaults, lower failures,
engine dispatch, jumps, chunk/event fields and order follow the original.
Stack failures retain preceding fields and return0, which the outer native
loader ignores before returning1. Host execution explicitly refuses invalid
stack storage. Negative/oversized memory writes are diagnosed, not reproduced.

ASM2834a5..2834b1 likewise passes the current GFF element as the fifth engine
load argument. Unknown output engine slots start at the element constructor's
zero value. Native jump insertion/updating is a separate provider; the current
live runtime refuses nonempty jump maps until actual hash ownership is ported.
Marker fixtures below prove dispatch, not that missing lower owner.

`ScriptSituationRuntime` now connects format save/load to canonical queued
actions through `ObjectStateRuntime`. Raw native code was retained in the prior
capture checkpoint. Current captures additionally carry SecondaryPtr0 and
ScriptEventID0 from the actual capture/constructor owners. File-backed NCS
contexts start with no NDB, empty jump map and empty chunk, matching native
ReadScriptFile/InitializeScript. Restored contexts retain actual NDB/chunk and
saved metadata; recapture shares the NDB and resets the two fresh-script fields
per native capture. Native PCs convert to/from host header-inclusive PCs; -1
remains a terminated execution pointer. No gameplay ID is allocated by these
primitive snapshot operations.

LoadActionQueue's local script pointer persists across parameters/actions.
Its callback now receives the prior pointer, so CodeSize0 preserves it. An
unwritten first pointer is explicitly diagnosed. There is no invented empty
script. Disposed snapshots cannot be saved. Synthetic legacy snapshots without
real code/capture metadata retain a precise unavailable-state diagnostic.

## Validation

- `inspect-native-script-situation-save.py`, finalv2:76 unchanged whole original
  saver cases compare full typed trees/struct IDs and engine dispatch. Includes
  code/NDB presence/empty blobs, primitive and engine/unknown CHAR types,
  independent original SP/captured SP/capacity, labels/SSO strings, raw jump
  origin BYTE, event/chunk and70 randomized cases. Heap/GFF/string/opaque engine
  saves are captured boundaries; native return1 is also checked even when a
  captured engine saver returns0.
- `inspect-native-script-situation-load.py`, finalv2:83 unchanged whole original
  snapshot/stack loader cases compare full output fields, typed payloads,
  retained output pointer, jump dispatch/update and ignored stack-error traces.
  GFF, successful DataBlock/shared-pointer/heap/string operations, physical
  jump storage and opaque engine loads are captured boundaries. It does not
  establish actual jump hash order or engine contents. Full lower input/output
  evidence and REA bodies remain in `backups/animations`.
- Initial load-focused-v1 caught the harness security-cookie callback clobbering
  RAX after native MOV EAX,1. The captured cookie helper now preserves RAX;
  both original oracles regenerated v2, and tests pass. Source loader behavior
  was not weakened to accommodate the bad return capture.
- `script-situation-runtime-focused-v3.txt`:60 focused tests pass, including
  both native comparisons, NDB/chunk/event/secondary round trip, recapture,
  prior-pointer retention, malformed/unsupported/disposed diagnostics, prior
  capture/action/script/talent/item/feat/event-clock and diagnostic checks.
  Build script-situation-runtime-build-v1 PASS; no full suite run.
- `installed-vm-capture-v3.json`:actual installed Prelude/wizard/active API with
  an explicit NCS fixture. Real STORE_STATE and ActionDoCommand capture top
  local123 from original SP3 into one cell/capacity17, nativePC39/hostPC52.
  Generic object-state saving emits the actual queued snapshot. Native action
  cancellation releases it, loading creates a fresh situation, re-saving is
  GFF-equal, and the real action runner resumes SetLocalInt and disposes it.
  The expected123 is observed; registry/allocator/effect IDs are unchanged.
  V2 separately tested SP1/cells1 before the stronger distinct-size case.
- `installed-item-save-v11.json`:previous real item/property/effect save/load/
  strict-expiry, primitive-action append/re-save and unsupported legacy-VM
  diagnostics still pass. Existing warnings and deliberately exercised errors
  are retained. Startup/general AI isolated; no shipped campaign claim.

## Open lower owners / next evidence

Live engine-structure save/load remains explicitly unavailable, including
effect/itemproperty/location/talent/event wrappers. The core format has real
dispatch points, not fake lower serializers. Full native engine Save552d60,
Load5521d0, Create50d170 and Copy50ce00 are saved/read; nested label is
`GameDefinedStrct`. Effect/itemproperty load uses constructor(1), then replaces
the ID from saved data. Generic object effect load uses constructor(0).
Already verified effect/location savers/loaders can be composed through these
actual wrappers next; event/talent lower owners have now been saved/read too.

Important event findings: CScriptEvent ctor4c6490 clears all four arrays and
capacities but does NOT initialize its type WORD. Do not invent type0 for that
unwritten field. EventUserDefined51d510 sets native type11 and integer slot0.
The current host command still has its legacy `{type:'userDefined',number}`
representation; its canonical migration/adapter and SignalEvent handling need
care. SpellCastAt already uses native type2/INT and object slots. Event Save
4c7070..4c728b writes EventType WORD and nonempty parameter lists with struct105
and label Parameter. Event Load4c6ba0..4c7067 appends, without clearing existing
arrays, using native capacity16/doubling. Talent Save49a570..49a638 and
Load497880..49798a copy seven typed fields; load defaults are0, distinct from
the talent constructor. Their complete native comparisons remain required.

ReadFieldVOID1a1870..1a1943 copies min(requested,stored) bytes and does not
initialize missing/tail bytes. Jmp Try_emplace279340..279528 hashes std::string
bytes with64-bit FNV-1a, matches full length+memcmp, inserts through its native
hash owner and updates duplicates without adding a node. Labels are C-string
truncated first. Actual physical insertion/rehash/copy ordering remains open.
SetUpScriptSituation285cf0 is now saved/read: it copies original stack size,
pointers/code/NDB/event, assigns jumps/chunk, transfers/clears the source stack
and resets the source map. No full native execution/lifetime completion claim.

Finish engine values, jump ownership and remaining VM lifetime/copy behavior,
opaque SQL/solver/JSON persistence, then full creature/CopyObject lifecycle.
The full spellcasting/combat/campaign objective stays ACTIVE.
Effect, event, location, talent and itemproperty engine payloads have since
been bound and original-code checked; see [engine-value persistence](vm-engine-structures.md).
Opaque engine values and native jump-map ownership remain open.

Verified checkpoint `backups/vm-snapshot-format-20261017-v1.zip`:
11534 files/175099563 bytes, every archived length and SHA256 verified.
Writer8868 terminal0 consumed; `vm-snapshot-format-checkpoint-v1.txt`.
This verification note was added after sealing.
