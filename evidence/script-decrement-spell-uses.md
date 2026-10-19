# Script spell-use decrement — 2026-10-17

Target NWN:EE89.8193.37-17 x64; SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game install/Ghidra project remain unchanged. Goal ACTIVE, single-player first.

## Native behavior and implementation

DecrementRemainingSpellUses581 maps to complete
**ExecuteCommandDecrementSpellUses1405155c0..515992**. The command is void;
return0 does not mean that a resource was necessarily consumed. Mandatory object
pop5155d4 precedes integer pop5155ec; either failure returns -639. No result is
pushed. Spell lookup515630 precedes creature lookup515699, including invalid
targets. Missing spells/creatures return0 without a fabricated resource pool.

Master handling preserves a native distinction between the spell pointer and
the selected numeric ID. If the first master differs, lookup51565a obtains that
parent. Success changes the ID to the **parent's own Master**, while retaining
the parent pointer for level/spontaneous metadata. A failed parent lookup
re-fetches the original spell at515683. It does not recursively normalize the
ID, skip the fallback lookup or replace the pointer with a guessed final row.

The class cursor/count are BYTEs. In original physical class order, only cached
SpellCaster==1 enters resource handling. Active class-table flags feed the same
native boolean projection as existing spellbook adapters.

- Nonmemorizing classes call GetSpellUsesLeft(spell,index,0,0). Any nonzero
  BYTE result obtains the level from the retained spell pointer and calls
  DecrementSpellsPerDayLeft515981, then returns0. There is no creature casting
  unlimited-flag shortcut in this script owner.
- Memorizing classes call stats GetMemorizedSpellReadyCount51571d; that wrapper
  delegates to the existing ClassInfo owner with metamagic255. A nonzero result
  obtains slot ID/details, requires the selected record's full DWORD spell ID
  and ready==1, and calls UnReadySpell. A nonzero full domain flag passes the
  selected level; otherwise it passes0. Metamagic is narrowed to BYTE.
- Only zero ready count and nonzero retained SpontaneouslyCast enter substitution.
  Slot count, level and candidate are repeatedly re-read in the original order.
  Candidate ready lookup515832 selects its own level/slot. The literal comparison
  at**515850 is against1**, not INVALID/-1; that gate is preserved. Matching
  details require ready DWORD==1 and pass the **BYTE domain flag itself** to
  UnReadySpell515961. This differs from the direct branch's level argument.
- Every attempted UnReadySpell exits the command, even if its lower returns0.
  It does not keep trying a later slot/class/innate ability after that attempt.
  Only exhausting class paths checks the innate list, gets the first matching
  ID's caster level regardless of readiness, and calls SetSpellLikeAbilityReady
  at51590e with ready0. Duplicate ID/level selection stays native.

`src/script_spell_uses.js` ports the whole coordinator with explicit lower
boundaries. SpellBookRuntime maps it to canonical creature data, ten live
known/memorized/per-day pools, active spell/class/domain/ruleset data and existing
verified uses/ready/unready/SLA owners. There are no per-spell effects or outcome
substitutions. Canonical engine enum gates are preserved where the original
uses them; fixture spell IDs are chosen from installed data.

Additional complete original accessors are mapped in spell_book.js:

| Owner | Address/range | Relevant behavior |
| --- | --- | --- |
| GetClass | 1403fa4a0..4c1 | BYTE class count/index, invalid255 |
| GetClassInfoA | 1403fa4d0..4ef | null outside current count |
| GetMemorizedSpellInSlot | 140404aa0..4b49 | DWORD ID/INVALID, warning on invalid level |
| ClassInfo slot details | 140404be0..4c64 | owning pointer/null, level warning |
| GetNumberMemorizedSpellSlots | 140405770..579c | BYTE count; invalid0 |
| stats ready-count wrapper | 140404f80..4fff | index>7 warns/returns0, else meta255 tail call |
| DecrementSpellsPerDayLeft | 1403f2790..2868 | zero wraps to255; count re-read after warning |
| GetIsInSpellLikeAbilityList | 140403340..3375 | exact ready INT==1 membership |

Normal UnReadySpell also reuses the mapped per-day decrement owner now. Its
existing native spellbook comparisons remain green; script decrement and normal
cast consumption retain their distinct unlimited-flag policies.

## Verification

**827 original-code cases PASS** (`native-decrement-spell-uses-v3.txt`):
497 whole wrapper cases and330 actual accessor/per-day cases. Native slot
pointer/count/details reads, class accessors, per-day mutation, SLA membership,
caster-level search and duplicate SLA mutation execute unchanged. Captured lower
boundaries are typed VM transfer, spell lookup/level, uses-left, ClassInfo ready
count and UnReadySpell. The latter owners already have independent comparisons
in [existing spellbook evidence](casting-spell-book.md). The new oracle is not a
full original VM, rule loader or entire casting/network simulation.

Cases include pop failures, target/spell failure, parent pointer/ID divergence,
missing-parent fallback, raw non1 flags/readiness, Byte wrapping, metamagic/domain
widths, substitution, later-class selection, ignored unready failures, duplicate
SLA levels and per-day underflow/invalid-index warnings.

**43 final focused tests PASS** (`decrement-spell-uses-focused-v3.txt`): new
owner/accessors, existing spellbook runtime/native cases, preparation, requests,
cast actions/live casting, rest resources and bonus feats. No full ~2,000-test
suite rerun for this change. Build-v1 and isolated offscreen casting UI-v1 PASS,
session14093 terminal0 consumed: book/radial/self cast, slots/hotbar targets,
cast animation/cancel and counterspell. A source-only explanatory comment about
native literal1 was added after that build; behavior is unchanged.

**Installed probev7 PASS11 checks**, using real parsed NCS581 and installed
wizard/cleric/sorcerer BICs in separate Prelude sessions:

- Prepared spell consumed despite the creature casting-unlimited flag; invalid
  target, area target and missing spell preserve all live pools and allocate no IDs.
- Prepared metamagic144/base0/Empower1 consumes the actual level2 record.
- Existing cleric domain186/level3 consumes the actual domain record.
- Domain/metamagic13/base2/Empower1 selects level4, then the original UnReady
  domain gate rejects level4 as its base domain. The script owner ignores that
  lower0 and preserves the slot, matching the native call path rather than
  forcing a decrement. This is a script-command compatibility case, not a claim
  that ordinary domain-metamagic casting should fail.
- Sorcerer known spell37 decrements level0 per-day6->5; repeated calls exhaust
  it to0, and a further call leaves the pool unchanged.
- A valid substitution31 consumes prepared38 after original preparation and
  ReadySpellLevel owners establish the fixture. No direct slot-ready writes.
- A real installed UTC `x3_diagolem001` consumes its genuine innate183/level15.
  Template discovery uses active data, not a per-spell production case.

Stock cleric BICs have no metamagic feats. The domain/metamagic fixture therefore
uses actual parsed-NCS EffectBonusFeat11 + ApplyEffectToObject, verifies native
HasFeat and unchanged permanent FeatList, then public RemoveEffect + scheduler
delivery removes the grant. Effect ID `0000000000000095` is retained as a full
canonical64-bit handle. This is a legitimate temporary feat path, not a bypass
of feature admission. All selected spell/class/domain/metamagic costs are active
data. Full rest/startup/general AI are isolated; no full item-cast/resource,
native UI notification, renderer/protocol/save or campaign completion claim.

Installed-v7 has no errors. Existing optional-table, inventory-owner, item/rule/
visual omissions remain recorded. Native helper warnings are emitted by runtime
providers rather than replacing failures with empty spell state.

Fixture failures are retained. Native-v1 shadowed the synthetic ability-list
address with a Python loop variable, corrected in v2; v3 extends the final827
cases. The first unit count assertion overestimated wrapper cases; value/status/
trace/state comparisons had already passed. Installed-v3 chose metamagic not
allowed by its cantrip; v4/v5/v6 exposed the stock cleric's lack of metamagic
feats and duplicate-domain UI-list filtering. Fixtures now read spell masks and
domain tables, use actual feat/preparation/readiness owners, and await their
completion. No original gate was relaxed or production result changed to pass.

Auditv61:840 spell rows,596 loaded impacts,**43 unbound calls /22 load failures**,
exit1 intentionally retained. Static instructions581 occur in generic helpers
included by x0_s3_clonefist/x0_s3_deckmany; their whole impacts are not accepted
by this probe. Clone-fist main first calls unbound CopyObject600, followed by
other gaps. Next research has complete CopyObject513500..51389c plus shared
SerializeToGff582760..583324 and DeserializeFromGff57f3d0..580912 dossiers.
CopyObject must serialize canonical live state and use native load/ownership,
not clone stale authored fields. These owners remain unimplemented.

REA files are `rea-decrement-spell-uses-wrapper.json`, the selected
`rea-decrement-*.json` accessors, and `rea-script-copy-object-owner.json` /
`rea-copy-object-{serialization,deserialization}-owner.json`. REA99283 was reused
and is idle. Other spells/effects/combat/campaign gates remain open. Verified
checkpoint recorded below; no subsystem or goal completion claim.

Verified checkpoint `backups/script-spell-uses-20261017-v1.zip` contains
11222 files/164291793 bytes. Every archived length/SHA256 verified;
session12349 terminal0 consumed, `script-spell-uses-checkpoint-v1.txt`.
This verification note was added after sealing.
