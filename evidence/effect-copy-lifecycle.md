# Effect construction, assignment and vision transitions

Target: NWN:EE89.8193.37-17 x64; executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The game installation and Ghidra database remained read-only.

## Verified distinctions

The complete copy constructor423570..423768 clears type, payload, links, tag
and exposure. It inherits the source uint64 ID, attribution, timing, property ID
and immunity override. Flag1 inherits icon visibility; flag0 leaves it zero.
It does **not** copy integer payload when flag1 is used. The eight updated owner
probes execute this original constructor, with heap/string/vector initialization
as explicit lower boundaries, replacing earlier captured full-copy assumptions.

Full CopyEffect423ce0..423f86 differs: it copies exposure, icon visibility, tag
and payload. It keeps an existing nonzero destination ID, inheriting the source
ID only when the destination ID is zero. Ghidra truncates at an intermediate
free; the complete assembly and original execution are authoritative here.

This audit corrected constructor copies in ability, haste/slow, movement speed,
attack count, invisibility, concealment, silence, enchantment/controller, vision
and spell-defense handlers. Their production provider now explicitly names
`copyConstruct`. The old ambiguous full-copy adapter was removed. Stat icons
already used the clearing constructor and now use the same explicit name.
Item-property materializers retain their separate, already mapped constructor
versus assignment modes; those were not globally changed.

## Beam and visibility owners

OnApplyBeam427a20..427ba6 constructs with flag0, then transfers exactly source
object0, integer0..2, float0 and both vectors. Other payload cells remain cleared.
The old blanket copy leaked unrelated integer/float/object/string cells. The new
implementation performs the explicit transfers; normal visual identity and
parent-group expiry remain shared. Accessor leaf CFGs are captured separately.

OnApplyTrueSeeing434990..434b1b and OnApplyUltraVision434be0..434d73 use clearing
construction for their own children. To suppress an existing darkness-blindness
record, however, they call base constructor4233d0 with argument1, then full
CopyEffect(...,0), change type73 to89, remove the old ID and apply the new value.
That sequence creates a **fresh effect ID** and preserves full source payload,
exposure and icon visibility. `assignFresh` now implements that distinction.

The reverse owners4392b0..4394d8 and4394f0..439718 call base constructor with
argument0 before full assignment: they **preserve** the inactive record's ID.
They allocate only if the record will be restored. Mode8 darkness is restored
only while canonical membership includes a darkness AoE36/345; other inactive
blindness modes are restored independently. `assignPreservingId` implements the
copy while existing removal/activation owners handle the world state.

OnApplyBlindnessInactive427f40..427fc8 has no creature admission gate and creates
icon10 using the clearing constructor. It now has a dedicated handler instead
of an inline full clone. Complete owner captures also cover the paired
blindness/darkness admission/removal and see-invisible paths.

## Validation

| Updated original-code probe | Cases | Actual copy-constructor executions |
|---|---:|---:|
| Ability v3 | 1,932 | 174 |
| Haste/Slow v2 | 303 | 324 |
| Speed/attack count v2 | 399 | 284 |
| Silence v2 | 110 | 66 |
| Enchantment v2 | 356 | 223 |
| Invisibility/concealment v2 | 242 | 59 |
| Vision v2 | 896 | 455 |
| Spell defense v2 | 498 | 198 |
| Total | 4,736 | 1,783 |

The separate copy-transfer probe compares1,240 beam, suppression and restoration
cases, executing complete base/copy constructors, full assignment, native ID
allocation and scalar/vector accessors. It covers noncreatures, visibility and
exposure flags, overlapping sources, multiple inactive records, darkness
membership and both restoration branches. Native lower application/removal are
captured sorted-pool boundaries; it does not claim all recursive handlers,
network delivery or every possible stale cached-index state are reproduced.

The first transfer fixture omitted the type75 sibling normally owned by admitted
blindness. The native Ultravision iterator consequently walked past that
synthetic pool. The fixture was corrected to include the normal sibling; no
production guard or original instruction was changed. Early missing-Unicorn
import failures were resolved by deferring helper imports until the existing
probe bootstrap had initialized its dependency path. Logs remain retained.

Installed `probe-installed-effect-copies.mjs` v1 passes seven unchanged authored
impacts: Bull's Strength9, Haste78, Invisibility90, Improved Invisibility88,
Ultravision365, True Seeing186 and Spell Resistance168. It checks real child
payload clearing and cleanup, then directly applies silence/fear/stun and an
active-table-selected beam73. Canonical actor/stat identities remain unchanged.
Darkness membership with actual recursive handlers confirms suppression creates
IDs a6/a9 from a4/a7 and restoration preserves a6/a9. These are effect IDs,
separate from canonical uint32 actor565. General AI/startup/entry are isolated;
direct impacts do not establish normal class eligibility/casting for each spell.
All load failures and unrelated diagnostics remain in the report.

The existing installed damage-buff probe v4 passes. Rendered `--polymorph`
regression passes real wheel selection, prepared parent-slot consumption,
authored form script, mesh/animation rebind, canonical identity and restoration.
Both PNGs were inspected: models/effects are present, but the scene remains dark,
partly occluded and locally overbright during the visual burst. This is not
evidence of complete lighting/camera or particle parity.

All1,652 regression tests pass (`effect-copy-full-tests-v2.txt`); build v2 passes
with the existing chunk-size warning. No required processes remain live. The
full spell/combat/campaign goal remains active;86 unbound impact API names and
22 missing NCS resources from auditv36, HUD buff art, broader casting/combat,
save/protocol and continuous campaign acceptance remain open.
