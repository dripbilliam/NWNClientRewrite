# Native item, property and visual saving

Target: read-only NWN:EE89.8193.37-17 x64, original
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This is another dependency of CopyObject600 and SaveCreature, not completion of
those calls or of general character export/import.

## Item and property owners

`src/item_save.js` ports the complete SaveItem coordinator
`14046b760..14046c125` and SaveItemProperties `14046c130..14046c41b`.
Shared object-state, visual and UUID saves remain explicit dependencies of the
item coordinator. A missing dependency cannot silently become an empty callback.

SaveItem flag0 calls SaveObjectState on the item's CNWSObject subobject first;
other flag values skip it. This differs from the outer CopyObject local-state
flag: the serializer calls SaveItem0, and separately avoids a second generic
SaveObjectState for items. The item owner writes its live names, flags, stack,
charges and appearance, using native widths. Hidden normalizes a full INT to a
BYTE boolean; several other fields simply narrow to BYTE. Pickpocketable also
checks the full cursed INT. DisplayName is omitted only when its stored length
is zero. Resource references preserve spelling and at most16 bytes.

Active baseitems ModelType controls appearance serialization: 0/1 write one
model part;1 also writes palette colors;2 writes three model parts;3 writes
palette, non255 per-part colors and19 armor parts. Unknown model types skip
these branches. Extended WORD fields include a legacy BYTE (zero above255)
and x-prefixed WORD. The original left/right thigh ordering is preserved.

Cost is stateful. Exact Plot1 and base-item enum69..73 produce zero without
recalculation. Otherwise a dirty price invokes CalculateBaseCosts and then clears
the dirty flag. Identified/unidentified price selection reads full INTs. Stack
threshold and multiplication use the full DWORD stack cell even though the
serialized StackSize is WORD. Multiplication wraps32 bits; applicable zero
results become1. These engine enum checks come from the original owner, not
from a spell/module-specific rule.

Container contents follow physical repository order. Null node values and stale
item IDs are skipped, but still count toward each child's GFF struct type.
Coordinates are captured before recursively saving a child and written as
BYTEs afterward. Child calls receive the same save flag. Cycles are diagnosed
rather than reproducing native recursion/heap faults.

SaveItemProperties always writes PropertiesList, active records then passive
records. Only duration BYTE exactly2 is included. Struct types retain physical
array indices, including skipped temporary records; passive types add the full
active count. It writes WORD/BYTE fields, remaining-use low bytes, and full
CustomTag strings. Runtime64-bit property/effect IDs are not converted to JS
numbers or added as invented serialized fields. `NativeItemRuntime.saveProperties`
now uses the canonical pools and reports failures through session diagnostics.

## Visual and UUID owners

`src/object_visual_save.js` and `ObjectVisualRuntime.save` implement:

- SaveVisualTransform `14049a780..14049a9b4`, using the existing verified
  all-zero-map predicate. It ignores clock caches/keys for omission, traverses
  signed scopes in order and writes all ten curves in native order.
- LerpFloat::WriteGFF `1402ea250..1402ea35a` and Progress
  `1402e9cd0..1402e9eee`. Progress can decrement repeats, swap endpoints and
  refresh clocks on the original buffer. Endpoint fields are written before
  sampling; flags/duration/repeats afterward. The existing RefreshInternally
  port is reused. Direct signed64-to-FLOAT rounding avoids a JS double-round
  at halfway points, retaining the native unsigned conversion sequence.
- SaveMaterialOverrides `140499f20..14049a227`, including the1024-record cap,
  full INT type dispatch versus BYTE type serialization, and fixed C strings.
- SaveTextureOverrides `14049a640..14049a76e` and SaveAnimationOverrides
  `140499c10..140499d3e`, with native16-byte GFF label truncation and preserved
  reference spelling.
- SaveMiscVisuals `14049a230..14049a34a`, which always writes its struct.
- CNWSUUID::SaveToGff `140505c70..140505cbc`, with existing member eligibility
  semantics and a stored-length gate. Ineligible types skip UUID string access.

Progress preserves the original early return when no world timer exists. World
subtraction return statuses are ignored and zero-initialized outputs retained
on failed calls; only their time component contributes to the native fraction.
Repeat refresh uses the shared world/monotonic-clock owners. None of this adds
renderer support for scoped transforms, shaders or texture replacements; those
existing presentation diagnostics remain visible.

## Validation and corrections

- `native-item-save-v2.txt`: **120 original-code cases PASS**, with typed trees,
  lower call order and dirty-price state compared by `item-save-native.test.js`.
  Original SaveItem/SaveItemProperties, resource-reference constructor and
  extended-field writer execute. Object-state/visual/UUID, price recalculation,
  property-color lookup and repository primitives are captured boundaries.
  Recursion, coordinate snapshots, skipping, field widths, duration filtering,
  model branches and cost coordination execute unchanged. This does not prove
  all captured lower owner bodies or whole-item runtime export.
- `native-object-visual-save-v1.txt`: **123 original-code cases PASS**, comparing
  typed visual output, curve bytes, repeat/clock mutation and lower call order.
  All visual/curve save and progress/refresh/zero-map bodies execute, plus the
  original reference constructor. GFF/string heap, clock/world-timer primitives
  and previously checked UUID eligibility are captured lower boundaries.
- `item-save-focused-v6.txt`: **29 focused tests PASS**, covering new owners and
  property, mutation, price, copy, appearance, visual-data/transform/runtime and
  UUID regressions. No full suite run.
- `item-save-build-v1.txt`: **PASS**, existing chunk-size warning. No UI flow
  changed, so no redundant UI smoke run.
- `installed-item-save-v3.json`: **PASS**, actual installed item selected using
  active ITEMPROPS/baseitems admission. Real parsed NCS adds permanent and
  temporary properties; only the permanent addition is saved. Public removal
  plus event pumping restores the baseline. Full effect IDs are retained as
  hex strings. A typed visual fixture passes through the real native load owners
  before saving curves, materials, replacements, misc fields and UUID. Imported
  resource records, registry membership and allocator IDs stay unchanged.
  No error diagnostics; existing unsupported/load warnings are retained.

Retained corrections: native-v1 captured resref conversion with an incorrect
lowercase assumption. Static InitFromCharArray190d30 proves case preservation;
v2 executes the actual18dea0/190d30 bodies. The comparison also caught reversed
left/right thigh indices in the new port; corrected before final verification.
Focused-v4 exposed a test-provider mismatch: the native failed subtraction
writes no outputs, while the JS fixture had supplied successful time fields
alongside failure status. V5/V6 preserve the real failed-call output behavior.
Installed-v1 incorrectly assumed the wizard had a right-hand weapon;v2 selected
a model2 weapon whose active ITEMPROPS column rejected the requested property.
V3 selects an admitted installed item using the real property type and physical
table column. Production admission gates were unchanged.

## Remaining work

The complete item coordinator is now bound as a whole-item live export; see
[generic state and installed validation](object-state-save.md). Nonempty opaque
VM/solver/JSON state still diagnoses its missing owner. Finish those owners,
SaveCreature and matching native loaders. CopyObject600
remains unbound until the lifecycle is real. General corrupt memory/allocation
failure, full renderer and campaign completion are not established by these
checks. The full spellcasting/combat/campaign goal remains active.

Additional native research: SaveCreature cleanup helper3aaff0 writes player-info
flags+24/+28 to1 when its captured flag is set; it does not restore arbitrary
previous values. Helper3aafc0 conditionally calls thunk140c4f024 with param1 and
0x18 when its char parameter is nonzero; its exact lifetime role is unproven.
These findings still need integration with SaveCreature's complete lifetime and
player-info owner. This wording was clarified after the checkpoint below.

Checkpoint `backups/item-visual-save-20261017-v1.zip` sealed successfully:
11341 files/168735990 bytes, every archived length and SHA256 verified.
Log `item-save-checkpoint-v1.txt`, process5776 terminal0 consumed. This
verification note was added after sealing.
