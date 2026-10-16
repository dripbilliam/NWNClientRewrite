# Client target preparation and innate casting

Target NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only Ghidra and hash-checked complete PE instruction captures were used.
Original install and Ghidra database remain unchanged.

## Parent targeting and normal activation

Quickbar type2 dispatch14085c8f0 calls target initialization140704500, then
setup140704720. Setup resolves the packed WORD spell, substitutes its first
SubRadSpell only for target/preview metadata and does not recurse. It retains
the original packed argument for callback140704300. The creature veto140704640
re-reads that metadata. Default automatic self-target BYTE141297120 is1 in the
original image. Masks1/5 auto-target self; mask9 does so unless inventory or
container mode is exactly1. Other masks register their physical target types.
Selection preserves class/domain/meta/conversion packed widths and actor XYZ.
The ordinary parent remains the submitted ID; radial chosen-child behavior is
separate. A new child selection popup on every hotbar activation would differ.

`src/spell_targeting.js` projects these target decisions into the existing local
targeter. The spellbook button uses the shared targeter as a local frontend;
original spellbook gesture handling is not claimed fully mapped. Full native
setup/veto/selection owners supply4,263 cases, including missing spell/child,
one-level lookup, inventory exceptions and packed fields. Spell/object access,
preview/render and final message providers are captured; GetSubRadialSpell runs
unchanged. Target range previews and configurable self-target options remain open.

Actual F2 parent130 casts its authored default werewolf form: pme0 becomes
c_werewolf and restores to pme0 after radial cancellation. Canonical player565
survives and the prepared parent130 slot is consumed. Report:
`live-polymorph-hotbar-ui.json`, `spell-targeting-hotbar-ui-v1.txt`.

## Spell-like input and shared casting

Quickbar type44 uses the same target initialization with ability callback
140704420 ->140804e20 ->1407bf6e0, sending message6/subtype35. Radial callback
1409a4610 shares140804e20. Spell WORD and caster-level nibble are distinct from
the class spell parameters. The local boundary is decoded input, not native
network serialization or authoritative server synchronization.

Server branch140454ba7..140454d3f retains packet/actor8ac/stats gates, checks
the active spell, manages actions and calls spell-kind0 talent wrappers
140380fb0/140380e20. Object talent resolves a creature and commandability, copies
its position and queries actor area twice; location talent checks commandability
without that area query. Both pass class254, domain/meta/conversion0 and supplied
caster BYTE to AddCastSpellActions. They ignore its return and return1 once the
enabled branch is entered. Input35 itself returns0 after dispatch; the UI now
says Ability requested rather than interpreting that as rejection.

`src/spell_like_input.js` and runtime adapters connect this to the canonical
player FIFO and existing queue/conjure/release/impact/consumption owners.633
original executions cover full dispatched input and the two spell/no-item
wrappers. Packet primitives, client/object/area lookup, feedback and lower
AddCastSpellActions are captured. Other talent kinds and item use are not claimed
implemented by these wrappers. Existing installed ability pools copied only in
memory cast location36 and object126, execute original scripts, play cast phases,
consume innate readiness1->0 and preserve class pools. This tests integration,
not every ability's effect or whole-campaign play.

## Innate radial and frontend

Special-ability root140994d10 adds innate subtree slot7 when client pool478 is
nonempty. Creator1409924a0 constructs the spell menu then traverses1409a3e80.
Seven entries use slots2/6/0/4/1/5/3; continuation7 saves the physical source
cursor. Per-page duplicate ID suppression keeps the first caster level. The
original duplicate branch increments the source cursor twice at1409a3fbb and
1409a417f, potentially skipping the next distinct entry; the replacement keeps
that behavior. Missing metadata consumes a slot. Count1408017c0 counts raw
nonzero ready entries with matching ID/level, wrapping BYTE. Disabled entries
combine this count and native target admission; selection masks WORD/nibble.
358 original traversal/selection cases cover order, holes, duplicates, overflow,
null pools and assignment context. Allocation/icon/string/presentation/spell
lookup and target admission are captured; native count executes. Target admission
was independently instruction-compared earlier. An initial fixture scratch-list
overlap was corrected; finalv2 observations andv3 comparison are authoritative.

The local Abilities tab and quickbar choices/drag use the canonical innate pool
and type44 fields. Self/world/ground wheels expose the innate subtree. The rest
of Special abilities remains partial: fixed Craft/Taunt/Search/Stealth requests
are diagnosed, and Class abilities at slot4 is an explicit local placeholder,
not the original adaptive class/feat layout. Count overlays, native class/feat
trees, UseFeat and special feat cast preflight, item abilities, replication and
all other spell owners remain open.

## Validation and retained failures

All1,575 tests pass (`spell-like-full-tests-v1.txt`) and production build passes
(`spell-like-build-v1.txt`). Hidden Electron --abilities FINALv3 exits0: two
original NPC126/caster8 GFF records are copied to an owned in-memory BIC; real
import, drag-to-F2, world self pick, first charge, innate radial second charge
and spent-entry disabling pass. Abilities rerender when their pool changes.
`live-spell-like-ui.json/png` retain requests, logs and screenshot. Standard
spellbook, self radial, F2 targeting/cancel, cast animations and counterspell UI
regression also passes (`spell-like-existing-ui-v1.txt`).

The initial ability UIv1 failed its blanket error assertion on the already-known
absent installed plc_w02.pwk during background perception. Finalv3 retains that
exact error separately (one occurrence), asserts no new failures, and does not
claim errors0 or a clean area. Screenshots still show existing darkness/camera
occlusion. Startup is disabled in fixtures; these are not campaign acceptance.
Static active auditv29 remains95 unbound names/22 missing NCS. Binding presence
is not implementation completeness. The larger spell/combat/campaign goal stays
active.
