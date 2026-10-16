# Polymorph construction, effect lifecycle and racial traits — 2026-10-15

Continuation: [full form lifecycle](polymorph-form-lifecycle.md) supersedes the
older unbound-type62 status below. Complete coordinators and Input30 radial
cancellation are connected; native combat snapshot/broader properties remain.

Target NWN:EE89.8193.37-17; original x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original install and Ghidra database remain unchanged.

## Connected behavior

Command463 EffectPolymorph now constructs the original type62 record through
`ExecuteCommandEffectComplex1405185d7..140518830`. Legacy calls with1/2 arguments
store no custom removal-VFX flag. Any argc>2 pops three additional INTs, so a
standalone3/4-argument call fails native stack pop(-639). Raw form/lock/VFX/caster
INTs survive; forms are not validated by the constructor. Payload is
`[form,0,locked,customVFX,visual,1,abilitySelector,casterOverride]`, subtype8,
with creator context set after choosing the ability.

The API calls its fourth argument a spell ability modifier, but this target
binary's unsigned<=5 comparison stores it as an ability selector. Other values
derive the selector from the current class slot, or the feat's source class,
then fall back to the first class when still255. Class casting ability255 selects
the primary ability. A missing creator leaves255. The implementation preserves
these observed branches; it does not replace them with the API comment's
literal-modifier interpretation. Missing/uninitialized class storage still fails
explicitly through the existing class provider rather than inventing a value.

Internal racial effect68 (`OnApplyRacialType140430be0`) is connected to
EffectRuntime. It reads WORD first-level feats from the active race FeatsTable,
not a playable-race switch. Feat228 creates an innate4 vision69/filter2 child;
feat354 creates filter1. These use copy-constructor flag0, keep the parent's
uint64 effect ID and set creator to the recipient. Existing vision/visual owners
produce the visual children. The handler does not itself rewrite Race or +770
vision flags. OnRemoveRacialType140437f00 returns1; shared group removal clears
the linked records and loops.

`LoadFeatsTable1402a1b1a..1402a1c00` imports a WORD physical row count. Every WORD
starts0; successful FeatIndex reads narrow to WORD. Holes, zero entries, duplicates
and order remain intact. IsFirstLevelGrantedFeat1402a19a0 returns0 for null storage,
otherwise scans these WORDs. EffectRuntime caches one loaded list per physical
race per active racialtypes table identity. Missing dependent resources remain
diagnosed by the existing resource loader. Invalid race pointers outside loaded
storage are explicitly unsupported, not guessed as human or an empty valid race.

## Implemented upper owners, not yet wired to type62 application

`src/polymorph_effect.js` also implements the full upper
OnApplyPolymorph140430950/OnRemovePolymorph140437c80 coordinators. Loading
dead/dying, associate7/8 and locked-form admission match the binary. The first
different-ID previous polymorph is marked completed and removed. Icon51 and
bonus feat289 precede the lower transformation call. Its return value is ignored
by this upper owner, and the client notification retains the raw lock INT.

Removal skips an ordinary destroyable dead NPC, but permits object-PC89c,
possessed familiar or nondestroyable paths. First removal optionally creates a
fresh instant VFX(default85), marks the same parent, sends reversal notification
and changes it to duration1. Ordinary removal sets a half-second world deadline
and returns0, retaining the record. A locked form or subsequent callback invokes
the lower restoration and returns1. Existing nativeField9f8 initializes0 from the
same constructor QWORD9f4 write; no duplicate lock-mode cell was introduced.

The full form/equipment transform140399e20 and restoration1403a5b50 remain lower
provider boundaries here. Type62 application/removal is deliberately not routed
to these upper coordinators until those lower owners are implemented. The
constructor binding alone does not make polymorph casting work.

## Evidence and limits

`scripts/inspect-native-polymorph-effects.py` executes the original full upper
polymorph/racial handlers, race feat loader/query and command constructor. The
original effect copy constructor/assignment, class-type getter, seconds conversion
and world addition run unchanged. Base/allocation/string/2DA/object/dead/dying/
client/nested-effect providers are captured; full transform/restoration and feat
source history are captured at their explicit lower boundaries. Loader scenarios
cover successfully loaded tables and empty/count-wrap cases, not the whole
failed-load warning/allocator lifecycle.

`native-polymorph-effect-observations.json` has1,815 handler/loader/query cases
plus1,932 constructor cases. Comparisons include raw inputs, metadata clearing,
copy flags, previous-ID groups, callback order, PC/dead/possession gates, custom
VFX, immediate/deferred reversal, day carry and creator/class/feat selection.
An integration test combines the actual new upper callbacks with existing icon,
bonus-feat, live ID-group removal and strict expiry owners. It proves retention
through500ms and reversal at501ms across a world-day boundary, while the lower
body transformation/restoration remain captured, not visually implemented.

Installed direct lifecyclev2 checks all seven standard race lists, real filters
and loops, group cleanup and canonical object/root/stats identity. Five constructor
contexts pass. Owned NCS bytecode invokes command463 through the actual VM using
the installed API declaration and verifies argument order/typed effect return.
These are not normal cast admission/release or rendered polymorph acceptance.

The actual installed `nw_s0_polyself` impact for physical spell387 now gets past
EffectPolymorph([3,0]) and fails at ApplyEffectToObject220, PC0x2f7, because type62
application is still unimplemented. This is preserved as an engine.unimplemented
diagnostic in `polymorph-authored-387-impact-v1.json`, not counted as a passing
polymorph cast. No cosmetic transformation or error suppression was added.

All1,566 tests pass (`polymorph-effects-full-tests-v2.txt`); production buildv2
passes. Final build hidden UIv2 passes (`polymorph-effects-live-ui-v2.txt`), covering existing spellbook/self and world radials,
F2 targeting/cancellation, slots, casting animation and counterspell, separately
from polymorph. Static active auditv27 has97 unbound spell-used command names,
22 missing NCS and840 physical spell rows. EffectPolymorph appears19 times across
nine impact scripts, all with legacy argc2. Binding count is not owner completeness.

Next: complete lower form/equipment transform and restoration, bind type62,
then model replacement, native client presentation and feat289/right-click cancel.
Full spells, combat and continuous campaign completion remain OPEN; goal ACTIVE.
Verified checkpoint: backups/polymorph-effects-1566-20261015.zip; see
backups/animations/polymorph-effects-checkpoint.txt for entry/hash verification.
