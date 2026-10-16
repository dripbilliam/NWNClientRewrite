# Object visual-data loaders and fixed GFF query labels

Subsequent continuation: timed/scoped transform owners, canonical runtime/
lifetime adapters, GIT placeable import and owned animation reload presentation
are now ported. See [current transform/runtime evidence](object-visual-transforms.md).
The older checkpoint results below remain historical evidence for these four
data owners and the label correction.

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original game resources, processes or Ghidra database entries were modified.
Fixtures/captures contain synthetic data and derived observations, not assets.

## Four data owners

`src/object_visual_data.js` ports these complete original bodies:

| Owner | Address/range | Stored state |
| --- | --- | --- |
| Material/ShaderParams | 140496ea0..1404972a9 | 108-byte records, pool2b8 |
| TextureReplace | 140497990..140497b9f | 34-byte records, pool2c8 |
| AnimationReplace | 1404969c0..140496bcf | 34-byte records, pool2d8 |
| MiscVisuals | 1404972b0..1404974ac | Cursor/color/distance/UI/bubble fields |

Full ASM: `backups/animations/placeable-template-tail-owners-v1.txt`.
These are serialized-data owners. Except animation import below, they do not
yet add shader/texture/bubble renderer bindings or client packet transport.

Missing/wrong-type root structures or lists retain previous pools. Valid empty
lists clear them. Valid pools reset their count/capacity and grow from16 by
doubling. Physical duplicate order and source case survive. Failed list elements
are skipped. Shader loading visits the first1024 physical rows, rather than
collecting1024 accepted records; Type BYTE1 reads an INT and Type2 reads four
FLOATs. Other types are skipped before reading names. Material and Param names
copy at most16 and64 bytes with separate zero terminators. Replacement records
contain two17-byte fields, copying at most16 bytes each.

The material record's two alignment bytes86..87 are not initialized by the
original owner. The port zeroes its buffer. The native comparison masks only
those two unspecified padding bytes, and a poisoned-stack fixture asserts that
the original indeed retains poison there. All defined record bytes, pool
capacity/count and other state are compared. This does not claim deterministic
native stack garbage or arbitrary raw-memory/packet parity.

A valid MiscVisuals struct reads every field, defaulting MouseCursor to-1,
RGB HiliteColor to-1, VisibleDistance to45, UiDiscoverMask to15, TextBubbleType
to0 and TextBubbleText to empty. Missing fields inside that struct therefore
reset their members; a failed root read retains the whole previous state.
FLOAT constants are captured in `object-visual-load-lower-v1.txt`.

`objectVisualDataGffProviders` connects these owners to parsed GFF metadata and
exact BYTE/INT/FLOAT/string/resref/struct/list field admission. Runtime storage
is owned JS buffers with explicit logical native capacity, not native heap
addresses or an OOM model. The new pools have not yet been added to general
object constructors/destructors or the placeable runtime adapter.

`inspect-native-object-visual-data.py` executes all four original owners across
167 fixtures, including native array growth, row-limit boundaries, missing/
noncanonical statuses, supported/unknown types, duplicate names, embedded NUL,
CP1252 bytes and stack poison. Typed GFF readers, fixed-byte copy, allocator/
free and cookie are explicit lower boundaries. Original loop/field-write logic
and record packing execute unchanged. Captures:
`native-object-visual-data-observations.json`, `object-visual-data-native-v2.txt`.

## GFF query-label correction

The parsed-file bridge exposed a concrete failure: the GFF writer correctly
rejects a20-byte serialized label named AnimationReplaceList. The native loader
nevertheless uses that longer literal. GetFieldByLabel14019fcc0..14019feef first
copies the query through a fixed16-byte buffer, then compares all four DWORDs
of each candidate serialized label. Thus AnimationReplaceList matches the
16-byte label AnimationReplace inside its parent structure; TextureReplaceList
matches TextureReplaceLi. Case remains significant and an embedded query NUL
terminates/pads the buffer. The serialized writer remains strict about its
16-byte label limit.

`nativeGffLabel` and shared `readNativeGff` now perform this query normalization.
`inspect-native-gff-label.py` executes complete GetFieldByLabel and GetField
14019fc20..14019fcbe against144 synthetic valid label/field-index tables.
Single/multiple fields, index permutations/subsets, case, longer literals,
embedded NUL and misses are checked. Only fixed-copy/cookie are boundaries;
there is no stubbed field lookup. Empty/null query diagnostics, corrupt tables
and duplicate serialized labels are excluded. The existing parser still
rejects duplicates and malformed data; this does not port native corrupt-file
recovery. Captures: `visual-gff-label-lookup-v1.txt`,
`native-gff-label-observations.json`, `gff-label-native-v1.txt`.

## Actual animation presentation correction

`importedAnimationOverrides` in `src/native_animation.js` previously queried
the full AnimationReplaceList property on a parsed JS object. Real GFF labels
cannot contain that full name, so overrides were missed. Parsed inputs now use
typed14/15/11 reads and the original query truncation. The semantic untyped
fixture fallback stays separate. Resrefs use the existing case-preserving
16-byte CResRef bridge, including supported CP1252 bytes.

The parsed-GFF test compares imported overrides with the full new record-pool
loader and verifies first-match animation selection. A presentation regression
builds a parsed UTC with the real truncated labels and drives
CreatureAnimationPresentation plus ModelAnimator: PAUSE1 resolves to cpause1,
the pose is sampled and the later duplicate does not replace it. Canonical
test-map object identity remains unchanged. This is a CPU scene/presentation
test, not a claim that all visual systems render correctly.

`probe-installed-object-visual-data.mjs` reads12 active installed UTC/UTP/UTM/UTW
templates through the resolver, then extends one installed UTC only in memory
to verify shader data, native label layout, first-match selection, missing-list
retention and explicit empty clearing. The12 sampled installed resources have
no authored visual roots; positive override coverage comes from the explicitly
reported in-memory fixture. Report `installed-object-visual-data-v1.json` and
log `object-visual-data-installed-v1.txt` both PASS. No fixture actor, resource
archive or copied game data is saved.

## Remaining dependency and checks

The five-tail call order remains in `placeable_template.js`. Visual transforms
497bb0 and its lower48f8c0, curve loader2e9ef0, restart helper2ea120 and
assignment49c020 still need complete ports and concrete ownership before UTP
templates/CreateObject243 are admitted. Their complete ASM is captured in
`object-visual-load-lower-v1.txt` and `object-visual-curve-owners-v2.txt`.
2ea110 is a verified tail jump to2ea120, not an independent unwind function.
An earlier combined capture errored on that missing unwind entry; the clean
v2 capture is authoritative. The helper schedules timer boundaries, not curve
interpolation coefficients. The native loader appears to read BehaviorFlags
and RepeatsRemaining then discard their results; verify by executing that
owner before porting. Scale/AnimationSpeed default1 and rotations/translations
default0. Timing uses two FLOAT multiplications by1000 in its monotonic branch.

All1,719 tests and production build pass. The existing bundle-size warning
remains. Installed waypoint/UUID/variables/area-movement/destruction regression
and rendered casting regression (spellbook, radial, hotbar, slots, animations,
cancellation, counterspell) PASS; owned processes are terminal. Logs:
`object-visual-data-full-tests-v2.txt`, `object-visual-data-build-v1.txt`,
`object-visual-data-world-template-regression-v1.txt`,
`object-visual-data-casting-regression-v1.txt`,
`object-visual-animation-presentation-v1.txt`.
Verified checkpoint target: `backups/object-visual-data-1719-20261016-v1.zip`;
terminal verification log: `backups/animations/object-visual-data-checkpoint-v1.txt`.
