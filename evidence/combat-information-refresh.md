# Native combat-information rebuild — 2026-10-17

Read-only NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. Generic engine/data owners are
ported; no spell or campaign exceptions. Single-player remains the priority.

## Owners and connected behavior

GetFilteredEffectList140390560..140390b56 returns original effect identities.
Kinds1/2 select attack10/11 and damage13/14 from their sorted cached starts.
Matching type/restrictions and equal spell IDs (or either spell=-1 wildcard)
replace an earlier record only for a strictly larger magnitude/active Rank.
Damage selectors include INT5; attack selectors compare only INT1..4.
Invalid kinds return empty; ties preserve the earlier pointer.

Complete UpdateCombatInformation1404171e0..140418522 now ports the native
orchestration: release/recreate d70, six ability-modifier caches, filtered attack
and damage nodes, basic attack count, ammunition properties/ranking, weapon IDs,
nominal attacks/damage, arcane failure, resistance, armor penalty, unarmed and
three creature-weapon dice/damage summaries, and critical values.
Constructor2a22b0 initializes owned scalars; node ctor2a2370 initializes six
bytes with race28. Arrays retain native16/doubling capacity. JS uses owned
arrays/scalars/IDs rather than fabricated native pointers or padding bytes.
Rebuild invalidates old node/text storage without replacing game objects.

Preserved native details include attack-node selector3 tested three times
(selectors4/5 leave node hand0), damage flags<8 special mapping, raw BYTE/WORD
wrap, signed armor/failure sums, main/offhand/double weapon distinctions and
ammunition raw-cost penalties versus Rank bonuses. All ammunition passive
properties are marked before ranking and cleared afterward. Alignment subtype9
does not cycle back to subtype0. Native scalar comparisons exclude unspecified
padding/pointer bytes.

Stats constructor1403ee50c/517 allocates d70 through2a22b0. The runtime creates
that owned state with the canonical creature. Two older dirty names now alias
ONE DWORD53c: combatInformationDirty/nativeEncumbranceDirty53c. QWORD538 ctor
clears its high DWORD;540 ctor14037b1e0 starts0. No second dirty state is kept.

Connected synchronous callers: arcane-failure setter415250, resistance setters
416b90/416ba0, equipment mutation and equipped-property add/remove callbacks.
The old synchronous-cache omission diagnostics were replaced by this work.
AIUpdate14037caac..14037caf8 now uses exact dirty gates/order:544==1 updates
memorized slots then spontaneous uses and clears544;53c==1 AND540>0 rebuilds
combat information then clears53c. Dirty state is re-read after spell callbacks.
Existing separately checked spell-book owners418a60/3f00a0 are reused.
The optional movement-debug branch remains diagnosed when its local flag is1;
its native configuration/message owner is not claimed implemented.

Runtime providers reuse active class/feat/item/ability/combat functions. Initial
equipment projections are included as the existing local representation of
imported item effects; projection records receive constructor-default spell=-1.
This is not proof that all initial native effect creation/import ordering or
every lower stat getter is complete. Native b0..bf constructor feat defaults
are FFFF; empty specialization/weapon-choice cells now preserve those values.
Absent legacy columns fail explicitly because their compiled fallback mappings
remain unimplemented.

## Validation

inspect-native-combat-information.py executes **1074 native cases**:
320 complete filter calls,677 complete rebuilds with real cache/node constructors
and GetInteger,76 bounded frame refreshes, one base-item constructor. Lower
stats/feats/items/2DA/old-cache destruction and heap/list storage are captured
boundaries. Tests compare identities, selected scalars, nodes, capacities, weapon
IDs, six modifier bytes, final property flags and ordered owner calls. Cover
negative BAB, monk/equipment branches, hand selectors, signed failure caches,
ammunition property families/ties, natural dice, critical feat paths, large lists
and callback mutation between dirty gates. No allocation-failure or complete
native heap/destructor comparison is claimed.

Accepted oraclev5. Initial v1 fixture gave two different base definitions the
same base ID; fixed in v2. Early implementation subtype9 mismatch fixed from
native result. v4 constructor fixture had an undefined buffer name, fixed in v5.
Failed captures/test logs retained. One linked-effects unit fixture intentionally
captures the new lower cache callback because it has no loaded creature stats;
real installed tests exercise the actual callback.

Installed cache probev1 PASS: actual NCS arcane failure and resistance rebuild
immediately, replace the cache and match script queries; actual full frame
consumes an attack dirty flag/updates nodes/removal; INT+4 updates prepared
slot counts and removal restores them. Native character-sheet consumer count1
is explicitly supplied by the fixture, not claimed as real GUI subscription.
Wizard slots [4,5,5,5,5,4,3,2,1,0] become [4,6,6,5,5,5,4,2,1,0] and restore.
Canonical registry identities and cursor remain unchanged. One existing trap
check omission retained, zero new errors/cache omission diagnostics.

All39 installed BIC cache/import consistency checks pass with real providers.
The broader load probe intentionally exits1 with load failures retained: missing
plc_w02.pwk and palemaster.bic HP102 computed/114 saved. These are not declared
clean loads. The HP difference predates this work (character-progression.md).
Additional observation confirms max102 before/after cache rebuild and GetHP,
classes wizard10/pale5, Deathless Vigor891 present, CON14/cache2. Native
GetMaxHitPoints391850 dossier agrees with the current min(pale,10)-4 formula;
independent original execution with this installed BIC remains the next check
before deciding whether the saved snapshot or implementation is wrong.

1910/1910 tests/build PASS; final polymorph hotbar/radial UI PASS terminal0.
Entangle/failurev16, Mightyv4 and bonus attacks/slots/Tenserv12 probes PASS.
Retained diagnostics drop as synchronous refresh becomes available; remaining
trap, presentation, polymorph snapshot and other omissions are not suppressed.

## Remaining integration

**Follow-up:** [Character-sheet/HP work](character-sheet-hp-refresh.md) now ports
the server subscription and statistics-update lifecycle, wires local decoded
UI requests and verifies actual-frame cache refresh without a consumer fixture.
All39 maximum-HP inputs independently match original execution; saved114/live102
is retained as a warning. Original client sender/writer, snapshot ownership and
campaign gates remain. The following paragraph describes the1910 checkpoint.

Character-sheet subscriber input/UI is not wired yet: native540 starts0 and
ordinary frame rebuilds require a real consumer. HandlePlayerToServerCharacter-
SheetMessage444e00, permission4bd020 and setter4be500 are mapped in retained
REA dossiers. Permission admits DM/self/owned associates; the handler decrements
old creature540, increments new540, updates displayed target/page, clears icons
for pageFF. GUI target change replaces its statistics-update owner. Native
client open/close/initial-message semantics and statistics-update lifecycle still
need mapping before connecting UI; do not substitute a blanket consumer1.

Polymorph still saves the labelled combat projection because native combat-info
copy ctor/assignment and snapshot ownership are separate unported owners.
Other native refresh callers (e.g. alignment/level validation), complete lower
stat behavior, messages, campaign and multiplayer acceptance remain open.
Goal stays ACTIVE; this is progress, not spell/combat/campaign completion.

Verified checkpoint: backups/combat-information-1910-20261017-v1.zip,
10229files/133804556bytes; every archived length/SHA256 verified, exit0.
This note was added after sealing; archive retains pre-verification notes.
