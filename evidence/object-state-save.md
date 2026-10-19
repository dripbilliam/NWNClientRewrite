# Generic object-state and live item saving

Target: NWN:EE89.8193.37-17 x64, original read-only `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This continues the item/property and visual owners in `item-save.md`.

## Original owners and implemented behavior

`object_state_save.js` ports the whole SaveObjectState14049a350..14049a470
coordinator and effect424d50..42510d, variables5080b0..508496,
location2e99b0..2e9a7b, action499910..499bf7 and transition4fe7e0..4fe845
savers. Full retained REA analyses are `rea-copy-save-object-state-owner.json`
and `rea-object-save-*.json` in `backups/animations`.

Effect IDs remain uint64 hex in canonical runtime storage and GFF DWORD64;
creator/object IDs remain DWORDs. Native duration/subtype filtering is preserved:
low bits3 are omitted; item saves retain only low bits1. A nonempty source
effect array still produces EffectList when every record is filtered. The
saver writes the original fixed-size payload lists and omits property/link IDs.
The native effect constructor4233d0 initializes SkipOnLoad to0; live effects
now carry this explicit field.

VarTable always exists, and each physical name emits float/int/object/string/
location/solver/JSON fields in native order when nonempty. Independent typed
cells under one name are retained. `script_variable_order.js` supplies original
hash-list order: byte xxHash32 seed0 XOR the empty hash, initial8 buckets,
load1, growth8x below512 then2x, bucket grouping and rehash order. Canonical
local-variable mutation and item copying retain this ownership metadata.
Find compares stored encoded lengths and C-string bytes within the native
bucket, including embedded-NUL behavior. Absent reads do not retain hash-cache
entries. Sources: GetHash16b780, byte hash16ca80..16cd24, native insert48b0d0,
find508c40, MatchIndex507f00, delete and constructor dossiers.

ActionList always exists; the client DWORD+d4 controls suppression. Local player
initialization sets it to0, matching constructor4b7840. Primitive parameters use
native widths/raw FLOAT bits; the original list label is literally `Paramaters`.
Unknown parameter types write Type alone. VM situations call an explicit owner.

Transition writes stored tag and target DWORD without resolving either. Its
whole LoadFromGff4fe610..4fe6d7 is also ported. An absent/wrong-type struct
retains state. Missing/wrong-type fields retain their previous values: assembly
4fe641 supplies this as the sixth string-reader argument, and4fe6b4 supplies
the current DWORD as the fifth argument. The decompiler omits the sixth
argument, so it must not be interpreted as an empty-tag fallback.

`ObjectStateRuntime` now binds canonical effects, local hash rows, actual native
action lists/client state and stored transition. `NativeItemRuntime.save`
connects the previously verified whole item coordinator to canonical scalar,
price, appearance, pose, repository, property, visual and UUID owners. Useable
is a dedicated generic-object field, loaded with BYTE-as-BOOL/default1, and
included in the current item-data projection. No authored snapshot substitutes
for current state. Container recursion follows registry IDs and actual repos.

## Validation

- `inspect-native-object-state-save.py`:57 unchanged original SaveObjectState
  cases executing all six lower save bodies; full typed fields and call order
  compare in `object-state-save-native.test.js`. Heap/GFF/client/list primitives,
  engine Empty/Save and VM situation calls are captured boundaries. Marker
  fixtures establish dispatch, not opaque engine/VM serialization completion.
- `inspect-native-script-variable-order.py`:70 original byte-hash cases and2354
  original insertion/find operations in14 scenarios, including growth to1024
  buckets, updates, delete/reinsert and embedded-NUL keys. `_Init` allocation
  and successful unlink are captured; delete endpoint rebuilding does not
  reorder physical nodes. The original deletion body is separately inspected.
- `inspect-native-object-transition-load.py`:14 unchanged original loader
  cases, including existing embedded-NUL tags, high IDs, missing and mistyped
  fields. Captured reader ABI confirms default pointers/values. V1 used
  pre-call stack offsets inside a callee and failed; V2 fixes the return-address
  offset and passes. Original code, unchanged, supplies both fallbacks.
- `object-state-save-focused-v5.txt`:37 targeted tests pass, including prior
  property mutation, item copy/save, visuals, variable load/order and actions.
  `object-state-save-build-v1.txt`:build passes. No full suite run for this change.
- `installed-item-save-v7.json`:actual installed Prelude/wizard/admitted item,
  real NCS permanent/temporary property mutation, complete item save with
  temporary effect ID138 retained as DWORD64, permanent PropertiesList,
  NCS local float/int/string/object/location, transition, visual/UUID and queued
  primitive parameters. Saving preserves registry IDs, allocation cursor and
  authored data. Unsupported VM state throws and remains in diagnostics.
- `installed-script-copy-item-v11.json`:all16 installed checks pass, including
  existing CopyItem allocation/locals/effect/acquisition/store/stack behavior and
  whole-save recursion through a real bag repository with child coordinates.
  Startup/general AI are isolated; all existing diagnostics retained.

Initial focused-v1 order tests exposed plain Array versus Uint8Array input;
the adapter now passes actual bytes. Installed-v5 failed only because a test
compared a parsed null-prototype GFF record with an ordinary object; the field
comparison was corrected. The native transition fallback review also corrected
the initial empty-tag assumption before the loader was verified.

## Remaining scope

This is not complete save/load, CopyObject, spellcasting/combat or campaign
acceptance. Nonempty solver/JSON locals and action type5 VM situations still
require real emptiness/serialization owners and are explicitly diagnosed by
the live saver. No synthetic capacity/PC/debug/jump state is supplied. Effect
and action import were explicitly unsupported at this checkpoint. Effect import
has since been implemented and verified through live application/expiry; see
[saved effect loading](game-effect-load.md). Nonempty action import remains
unsupported. Full
SaveCreature, lifecycle and deserialization still precede binding CopyObject600.

Next original research retained: whole LoadObjectState4974b0..497609 loads each
effect into a fresh constructor(0), calls LoadGameEffect4246d0..424d49, destroys
SkipOnLoad==1 or duration-lowbits3, otherwise ApplyEffect(object,effect,1,0),
then variables/actions/transition. The complete LoadGameEffect static body is
saved/read, but not ported or original-code checked yet. Native SetCreator
must remain a real dependency; the fixed lists have native missing/short-list
behavior, and integer count/list mismatches require explicit diagnosis rather
than unsafe writes. See `rea-object-load-state-owner.json` and
`rea-object-effect-load-owner.json`. The full user goal remains ACTIVE.

Verified checkpoint `backups/object-state-item-save-20261017-v1.zip`:
11405 files/170558856 bytes; every archived length and SHA256 verified.
Writer session68001 terminal0 consumed, log `object-state-save-checkpoint-v1.txt`.
This verification note was added after sealing.
