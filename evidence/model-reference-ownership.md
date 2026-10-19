# Reference models in spell visuals — 2026-10-17

Dynamic casting, projectile and looping-visual assets now prefetch reference
resources, create an independent child model for every physical reference part,
attach it by the authored part name and dispose it with its owning part. Reference
nodes also enter the existing native transform-controller path. Static area model
references, linked projectile initialization7/12 and native reattachment remain
open. This is progress toward the full goal, not completion of spellcasting.

Original target NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain read-only. No proprietary resource was
copied into the workspace. The goal was explicitly resumed after the prior pause.

## Native ownership evidence

CreateReferenceObjects14008db90..14008dc59 queries Part virtual70. For a reference
it checks header flags98&0x11, calls NewCAurObject1400931f0 with header modelA0 and
null alias/file, stores the result in PartReference68, obtains the part name from
virtual8 and invokes child model virtual98(owner,name,0). It then visits physical
children in order, recursively, re-reading the count. ReattachableE0 does not gate
creation; it gates the separate later ReattachReference owner. Failed native
header/model lookups would dereference invalid memory. The port throws explicit
errors at those boundaries instead of inventing a replacement model.

NewCAurObject calls this after CreateInstanceTreeR14008dab0 and Part::PostProcess
140093aa0, for main and optional LOD trees. Gob::Append14008c0c0 also invokes it
after attaching an appended tree. ExpandReferenceParts1400c92a0 is a different
scene/tile path that adds a child Part tree with no Gob; it was investigated but
is not substituted for the dynamic model-reference owner.

PartReference vtable140d88208 virtual0 is deleting destructor14008acf0. It destroys
nonnull child68 with flag1, then invokes Part::~Part140089d20, and frees the78-byte
part only when incoming flags bit0 is set. InternalCreateInstance140091af0 and its
wrapper140092e40 do not themselves populate68. This resolves the missing ownership
question from the preceding parsing increment.

Reference InternalControl1400524d0 queries AsPartReference and ignores its return,
then tail-calls base MdlNode::InternalControl140051c50 with the original float
arguments. There are no additional reference transform channels. The previous
renderer guard rejected reference and animated-vertex flags together; reference
control now delegates through this owner, while animated-vertex control retains
its explicit unsupported error.

`scripts/inspect-native-model-references.py` executes original creation/destruction
and controller wrappers.62 cases cover tree ordering, reference/non-reference
parts, stored ownership and destructor flags/presence.32 further cases cover float
arguments and both nonnull/null cast results. Allocation/model creation, lookup,
attachment, base control, Part destructor and free are captured lower boundaries;
these cases do not prove their entire native implementations. REA dossiers are
retained as `backups/animations/rea-reference-*.json`.

## Rendering and resource boundary

`loadModelReferenceAssets` prefetches active resources without instantiating them.
Shared names reuse immutable asset data, but every reference creates a separate
render model and animator. Missing resources release acquired assets; reference
cycles fail with a recorded load error. Cycle rejection is a local recovery guard,
not a claim that native recursion recovers similarly.

`ModelReferenceScene` uses the existing checked P/Q attachment adapter. It follows
animated physical anchors without inheriting their scale. Nested instances update
in parent order. Reference cleanup is idempotent at the scene boundary, retains
native child-before-part ordering and releases each acquired resource once. No
gameplay object or canonical ID is allocated for a referenced model. The renderer
still uses asynchronous resource I/O and its existing local clock/scene adapters;
complete native cache, naming, LOD, culling and scheduling parity is unproven.

The unsupported-reference diagnostic is suppressed only for the dynamic visual
asset path that now instantiates references. Other model-loading paths retain
their diagnostics. Missing child assets and failed attachment/update remain logged.

## Validation

- All1887 tests and production build pass. Build retains its bundle-size warning.
- Native comparisons:62 ownership and32 reference-controller cases.
- Scene tests: repeated/nested references are distinct, moving/scaled anchors
  preserve child P/Q attachment, cleanup frees all instances, and missing/cyclic
  resources release partial loads.
- Installed inventory examines210 of810 active v*/fx* candidates until finding12
  reference-containing models. This is a bounded sample, not complete coverage.
- Headless installed verification loads those12 unchanged MDLs, inherits clips,
  runs real ModelAnimator/native poses and checks34 instances through animation,
  anchor movement, scale independence and cleanup. It does not assert mesh pixels.
- Actual casting UI selects a prepared spell from active data whose conjure model
  contains a reference. Here it selects spell58, vpr_fireball/path1, with authored
  vco_mehanfire03 -> fx_ref. It observes the child, verifies its animated pose
  changes, then verifies cleanup. Chant, CC8 text, conjure/fade, projectile travel,
  body impact and cleanup also pass. There is no spell-ID runtime exception.
- Ordinary installed Daze projectile/casting regression passes too.

Initial headless installed verification exposed the old reference-controller
guard; it passes after connecting the native wrapper. Initial reference UI timed
out because its higher-level prepared spell entry was below the visible panel;
the test now scrolls the actual entry into view before clicking. UIv2/v3 pass,
with v3 additionally asserting that the reference child's pose changes.

Retained captures: native-model-reference-owner-observations.json,
installed-model-reference-inventory-v1.json,
installed-model-reference-ownership-v1.json and live-model-reference-ui.json in
backups/animations. Final tests/installed/UI processes are terminal. Checkpoint
verified: `backups/model-reference-owner-1887-20261017-v1.zip`,9906 files,
127068390 bytes. Every archived entry length/SHA256 was verified; process31801
finished with exit0. These verification notes were added after sealing.

## Next unresolved owners

Continue Gob::ReattachReference140093b50 composed native verification, linked
initializer7 and random reference initializer12. `fx_ref` is an installed dummy
MDL; a resource lookup for `ref` fails. Do not substitute fx_ref or invent ref.
FindModel140098cd0 checks the model cache first, then IODispatcher::ReadSync, with
no observed ref-name exception. The creator of any cached ref model or dispatcher
source still needs tracing. Kind7's no-reference case must retain the native no-op.

Static area reference expansion, scene-hit/child projectiles, moving-loop audio,
shield equipment/model binding, full client replication, remaining effect calls,
combat completion and campaign playthrough remain unfinished. Goal stays active.
