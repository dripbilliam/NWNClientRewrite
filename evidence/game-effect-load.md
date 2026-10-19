# Saved effect loading and application

Target: read-only NWN:EE89.8193.37-17 x64, `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Continues `object-state-save.md`.

## Owners

`game_effect_load.js` ports the whole LoadGameEffect1404246d0..140424d49.
Typed scalar fallbacks, widths, BYTE-as-BOOL, uint64 effect ID, packed subtype,
integer reallocation, custom tag, immunity and all fixed payload loops follow
the original. Missing fixed lists retain prior payload; short lists reuse the
same CResStruct local after failed GetListElement. GetListElement1a03f0's whole
body proves failed calls leave the output untouched. An uninitialized first
element, negative allocation and IntList overflow are explicitly diagnosed.
No arbitrary reordering, padding or invented pointer/link/property fields.

SetCreator425110 runs before saved spell/caster metadata overwrites the current
fields. The live bridge calls the existing native creator owner, including AoE
attribution. The saved creator/other object IDs stay DWORDs. Effect IDs remain
full16-digit hex strings. Whole effect constructor4233d0 with argument0 is
represented by savedEffectStorage: it allocates payload storage but does NOT
consume m_nNextID; exposure/icon0, invalid creator/objects, spell/caster-1 and
property ID0 are explicit. This is distinct from the script constructor(1).

`object_state_load.js` ports the whole LoadObjectState4974b0..497609 coordinator:
effect constructor(0), actual loader, exact SkipOnLoad==1/duration-lowbits3
disposal, ApplyEffect(loading1,special0), variables, actions, transition.
`ObjectStateRuntime.load` binds live loading and application. Native item loading
now calls it; saved temporary item properties therefore enter the actual active
or passive pool through ITEMPROPS admission and native application callbacks.
Loading preserves the stored expiry through the existing effect-clock owner.
Discarded unlinked plain effect storage is reclaimed by JS ownership; no native
heap, pointer or property ID is fabricated. Nonempty saved action queues remain
explicitly unsupported until LoadActionQueue and VM-state ownership are ready.

Effect copy constructor423570 clears SkipOnLoad to0, alongside its existing
payload-clearing behavior. The runtime now performs this additional reset.
Full retained analyses: `rea-object-effect-default-constructor.json`,
`rea-object-effect-copy-constructor.json`, `rea-object-effect-load-owner.json`,
`rea-object-load-state-owner.json`, `rea-object-gff-list-element.json`.

## Validation

- `inspect-native-game-effect-load.py`:95 cases execute the unchanged whole
  original loader. Compare full effect snapshots and typed-reader/creator call
  order. Cases include64-bit IDs, missing/wrong-type fields, restored payload,
  retained absent lists, short/empty fixed lists after a valid prior struct,
  integer zero fill and BYTE-as-BOOL values0/1/2/128/255. GFF, heap, string
  assignment and creator are explicit captured boundaries; separate existing
  creator/string evidence is retained. Allocation failure and corrupt memory
  writes are not claimed safe or compatible. Log native-game-effect-load-v1.
- `inspect-native-object-state-load.py`:7 cases execute the unchanged whole
  original coordinator, with captured constructor/payload/application/lower
  owners. Exact skip values0/1/2/-1/256, all eight duration-lowbit values,
  construction0, ApplyEffect flags1/0 and lower-owner call order compare.
  This capture alone does not establish payload or ApplyEffect correctness.
- `game-effect-load-focused-v2.txt`:26 focused tests pass: both original-code
  comparisons, live skipped-effect/ID behavior, effect payload malformed-state
  diagnostics, copy reset, item wrapper/load, save, creator, property mutation
  and vision application/removal. Build game-effect-load-build-v1 PASS.
  No full suite run.
- `installed-item-save-v8.json`:actual installed Prelude/wizard/admitted item
  and real NCS property mutation, full item save and LoadFromGff(loading1).
  Fresh canonical item574 restores temp effect000000000000008a with stored
  deadline and a genuine allocated property ID. Effect allocator advances only
  for permanent PropertiesList construction, not restored effect IDs. The temp
  property remains exactly at expiry, disappears just after it, and permanent
  properties remain. Earlier whole-save/local/visual/action/unsupported-VM
  checks also pass. Startup/general AI isolated; diagnostics retained, including
  deliberately exercised unsupported VM save and existing resource warnings.

## Next / limits

LoadActionQueue4963f0..4969a2 full body is saved/read in
`rea-object-action-load-owner.json`. It appends through native AddAction rather
than directly restoring count/group counters.12 temporary parameter slots are
zeroed; count and nested-list failure handling retain native locals. Primitive
parameters are heap temporaries copied by AddAction, types4/5 have actual
owned-string/VM behavior. The spelling remains `Paramaters`. Failed inner
GetListElement retains its CResStruct across parameters/actions. Type5 loads
Value struct through LoadScriptSituation_Internal; unknown types have no
initialized disposal-type slot. These require original-code checks and explicit
corrupt-state diagnostics, not a guessed direct node import.

The primitive queued-action owner has since been connected and original-code
checked; see [saved action restoration](object-action-load.md). VM type5 remains
explicitly unsupported by the live runtime.

VM script-situation save/load, opaque solver/JSON serialization, whole creature
save/load/lifecycle, CopyObject600, remaining spell/combat/campaign work remain
open. This is a verified generic item-effect restoration cycle, not full game
save/load, complete spellcasting or campaign acceptance. Goal remains ACTIVE.

Verified checkpoint `backups/game-effect-load-20261017-v1.zip`:
11426 files/171100209 bytes; every archived length and SHA256 verified.
Writer session30961 terminal0 consumed; `game-effect-load-checkpoint-v1.txt`.
This note was added after sealing.
