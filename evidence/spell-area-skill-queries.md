# Area and skill queries used by spells — 2026-10-16

Bound GetIsAreaAboveGround726, GetIsAreaInterior716 and GetHasSkill286 using
canonical objects and existing active skill/class rules. The spell-impact audit
now reports **77 unbound commands /22 missing resources** (v38), down from80.
These commands occur in mount, Deck of Many Things and Clone Fist impact scripts;
their presence does not establish completion of those effects or scripts.

Native target is the unchanged NWN:EE89.8193.37-17 x64 executable, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The persistent REA session supplied the complete named function dossiers; the
instruction bodies were separately read and exercised with the existing emulator.

- **AboveGround1405269d0..140526a43**: lookup must return an area, not the area
  of any supplied creature. Missing/wrong-kind objects return **-1**. Valid
  areas read the low byte of field+8, invert it, shift1 and mask1.
- **Interior140526a50..140526acc**: missing/wrong-kind objects return **0**.
  For a valid area, **either** of the two low flag bits makes the result1.
  This is not simply the first bit. Product bindings use live `area.flags`,
  already shared with protocol field8 by `nativeMessageField`; a cached import
  or inferred tileset/environment classification would drift from that owner.
- **GetHasSkill140525700..1405257d3**: pop skill/object, check the low-byte
  object-array lookup status, cast AsCreature, cast a second time, and call
  GetCanUseSkill with the **BYTE** skill ID. Only lower result **exactly1**
  returns1; generic truthiness is wrong. It asks skill eligibility, not effective
  rank>0. Missing/noncreatures return0. The binding calls the existing
  `combat.canUseSkill` / `skill_rank.canUseSkill` lower, retaining active rules,
  DM, trained-base-rank and per-class usability handling and special-skill
  mappings. No new class/skill tables or module-specific defaults are introduced.

`scripts/inspect-native-spell-area-queries.py` captures **4,160 complete original
area wrapper cases**: all256 flag-byte values, high-byte values, missing lookup,
typed-pop/push failure and exact object-ID forwarding. `scripts/inspect-native-
script-has-skill.py` captures **3,072 complete original skill wrappers** including
skill narrowing, lookup status/cast order, exact return1 and failure contracts.
VM/object lookup/virtual casting and GetCanUseSkill are captured lower boundaries;
the latter retains its earlier independent native tests. This is not a new
whole-VM or whole-skill-system oracle. Push/pop error returns remain-638/-639.
Both new golden tests pass; raw outputs are the corresponding `native-*.json`
records and successful capture logs. Unknown host provider state is diagnosed.

`probe-installed-spell-area-skill.mjs`, final v2, passes real parsed NCS dispatch
over all five installed Prelude areas, canonical PC/area/nonexistent targets,
live flag changes reflected through the protocol alias, and installed skill
eligibility including byte-wrapped IDs. No object IDs are allocated. This checks
dispatch into the existing native-tested eligibility lower, not a second
independent full rules implementation. The RAM-only probe restores area flags.

**1,765 tests PASS** (`spell-area-skill-full-tests-v2.txt`), build PASS
(`spell-area-skill-build-v2.txt`), installed probe PASS. Prior rendered casting
regression passed at the preceding helper increment; these subsequent read-only
queries were verified by native/VM/model checks, without claiming a mount UI test.

GetImmortal remains unbound while the backing-field/load ownership is checked.
Its native getter reads raw INT+8b8; a Boolean approximation or unrelated GFF
snapshot must not substitute for that owner. CopyItem and other spell/combat
dependencies also remain open. Work continues under the user's resume request.
