# Linked projectile model reattachment — 2026-10-17

Linked initializer kind7 and the kind12 random-linked graph tail now reach the
renderer through native model-reference ownership. Native breadth-first
reattachment, successive raw quaternion updates, auxiliary P/Q/scene transfer and
auxiliary-before-main cleanup are ported and checked. Canonical gameplay IDs and
server RNG remain untouched. Full spellcasting/combat/campaign completion remains
unproven; this increment is progress toward the active goal.

Read-only target NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original installation and Ghidra project unchanged. No proprietary assets copied.

## Original reattachment

Gob::ReattachReference140093b50 traverses the main physical part tree breadth
first, preserving child order, including queue reallocations. Reference virtual70
must return nonnull; header flags98 must contain0x11, reattachableE0 must be nonzero
and child model68 must be nonnull. It attaches that child through virtual98 to the
given object/part, or restores this Gob and the reference part name for a null
target. Header admission failures simply skip that part.

After attachment it reloads model68, gets its global position through virtualC0
and subtracts this Gob's A8/AC/B0. Current quaternion B4/B8/BC/C0 has native order
w,x,y,z. The forward vector is exactly [2(zx+wy),2(zy-wx),1-2(x²+y²)], retaining
SSE float grouping. RotationArc14022e1c0 maps that forward vector to the delta;
operator*14022ab00 multiplies arc * current quaternion. The routine stores all four
components directly, without normalization, before visiting the next eligible
reference. With no eligible reference, reattachment is a true no-op.

`scripts/inspect-native-reference-reattach.py` runs that complete original routine
with actual RotationArc, Vector::Normalize and quaternion multiplication.783 cases
cover reference masks, invalid header flags, zero/nonzero/negative reattachable,
missing child models, null targets, zero/non-unit quaternions, zero deltas and
1/17/33-part trees forcing queue growth. Attachment, position query, part casts,
allocator/memmove/free and host IEEE sqrt are captured lower boundaries. Tests
compare the complete call sequence, intermediate stored Q values and final raw Q.

The scene bridge uses the existing checked P/Q attachment service, so reattached
children follow a moving external anchor without inheriting its scale. It can
restore authored anchors on null-target reattachment. Native global scene/cache,
visibility/LOD and object-destruction notification parity are still unverified.

## Projectile initialization and destruction

Full initialize140987f10 retains its common target/delta and near-zero admission.
Kind7 then zeroes velocity204..20c and acceleration210..218, queries projectile
model virtual140(255,1), requires a client array, and looks up its target. For a
resolved target with a model it queries the model twice before the named part
pose, then queries it again and reattaches to the cached part or root fallback.
A resolved target without a model is left alone. Failed lookup creates
NewCAurObject("ref","dummytarget",null), stores it at230, sets it to node point and
reattaches to its root if creation succeeded. Kind7 never enters ordinary motion.

Kind12 retains the previously checked shared CRT/RNG mathematics. Its graph tail
creates NewCAurObject("ref","",null) at230. On success it copies projectile model
position to the helper, moves the original model's native Z by float32(.01),
copies the raw quaternion and scene to the helper, then reattaches to its root.
This changes model transforms, not the projectile object's stored position38.
Get/SetPosition use hidden result-vector storage; SetOrientation uses its hidden
result quaternion. No extra random draws or invented target movement are added.

Vtable140e72b98 virtual0 resolves to deleting destructor140983820, which calls
body1409835c0. That body detaches auxiliary230 through virtual98(NULL,NULL,0), clears
its scene through virtual90, destroys the reloaded pointer with flag1 and clears
230 before clearing/deleting main model handle78. The local helper is never
AttachToObject-parented, so that detach is already unbound; actual scene removal
and model deletion still occur in native order. The optional asset factory owns
its prefetched resources independently of canonical game objects.

`scripts/inspect-native-linked-projectile.py` executes the complete original
initializer with actual vector/random math and captured model services.97 cases
exercise kind7/kind12 lookup, model/pose/array presence and auxiliary success/null.
Four full destructor-body cases capture auxiliary/main presence and ordering,
with array/list/base/model destruction as lower boundaries. Together with the
783 reattachment cases, this increment adds884 original-code comparison cases.

## Asynchronous resources and the absent ref model

The renderer prefetches optional `ref` data for paths7/10 before synchronous native
initialization. Path10 configures kind12 through the existing native configurator.
Prefetch is local adapter work, not an extra native engine call. Failure is logged
with that distinction; if requested, NewCAurObject then returns null. It does not
invent or substitute fx_ref, and the projectile continues through the original
allocation-failure branch. A provided active resource creates independent models.
Late prefetch completion after disposal releases assets without resurrection or
double deletion. A receive-wrapper argument drop found by the new tests was fixed
so the selected override path reaches this prefetch boundary.

The active install has an actual fx_ref MDL, but no ref MDL in its resource index
or loose files. FindModel140098cd0 checks BinarySearchModel then
IODispatcher::ReadSync; it has no observed ref-name exception. The verified image
contains one exact ref literal140e72ef4, referenced by the two initializer sites.
No embedded "newmodel ref" text was found. These observations do not prove the
contents of a running native model cache or dispatcher registration, so native
endpoint availability is not claimed beyond the captured null/success branches.

Reference-node constructor140087740 sets flags/callbacks but does not initialize
its extra model/reattachable cells. No guessed ASCII default was added when that
metadata is absent; malformed/uninitialized reference data remains diagnosed.

## Validation and limits

- All1895 tests and final production build pass; bundle-size warning retained.
-884 original-code cases, plus replacement-after-attachment and no-reference
  no-op checks. Existing random math/control tests remain passing.
- Renderer integration checks both endpoint success/null, native initial transforms,
  endpoint-before-main deletion, unchanged canonical ID cursor and late I/O cleanup.
-12 installed effect MDLs,46 instances: reference eligibility, moving external
  attachment, quaternion update, authored-anchor restoration and cleanup pass.
-10 installed projectile cases: four active linked spells/models with absent and
  present canonical c_dummy targets, plus path10 appearance7 override on an active
  ordinary spell with both target states. Actual hierarchy, ModelAnimator, native
  orientation and P/Q services are used. Endpoint resource absence is retained in
  diagnostics, and the probe also supports an available active ref resource.
- Ordinary Daze and reference-containing Fireball casting UI regressions pass:
  chant, CC8, conjure/reference animation, fade, projectile travel, body attachment
  and cleanup. These are regressions, not an in-world UI acceptance test of every
  linked spell/weapon or the actual native network transport.

Initial synthetic queue-growth fixture overlapped its child array and vtable; its
arrays were moved to separate allocations before accepting the native capture.
Initial presentation checks caught the dropped path argument and corrected a
fixture that disposed before prefetch had actually begun. No failed run is counted
as passing. Final tests76566, nativev3, buildv2 and both UI commands are terminal.

Captures are under backups/animations: native-reference-reattach-observations.json,
native-linked-projectile-observations.json, installed-reference-reattach-v1.json
and installed-linked-projectile-v3.json. Verified checkpoint:
`backups/linked-projectile-1895-20261017-v1.zip`,9956 files/128169068 bytes.
Every archived entry length and SHA256 was verified; process66967 finished with
exit0. Verification notes added after sealing.

Remaining work includes scene-hit paths8/11/12/13, child projectile spawning,
moving-loop audio, shield equipment/model binding, complete client replication,
static area reference expansion, unresolved spell/effect calls, combat completion
and campaign playthrough. The full goal remains active and incomplete.
