# Curse, Ethereal and personal-reputation script commands — 2026-10-17

Read-only original NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original install and Ghidra project remain unchanged. No spell-specific
runtime implementation or replacement impact scripts were added.

## Native evidence and implementation

`ExecuteCommandEffectComplex1405180b0..140518926`, ordinal138, constructs
type45 with six signed INT magnitudes. No-argument native calls default all
six to1; positive arity pops all six. `OnApplyCurse1404281a0..140428658`
rejects plot creatures and checks immunity17 unless bypassed, with feedback141
to the source when present and then to the target. Loading rejects dead targets
except duration3/4. Noncreatures return0. The constructor and handler are ported
in `src/curse_effect.js` and bound through the existing VM/effect runtime.

The handler copies six type37 ability-decrease children with the same uint64
effect ID. STR/DEX apply directly; CON queues zero-delay AI event5 with the
original creator and target IDs; INT/WIS/CHA apply directly. Then a copy with
icon visibility inherited produces type67/icon22. The existing ability owner
handles score floors, immunity, attribute caches, CON hit points and icons.
`OnRemoveCurse140436290..140436295` returns1; the existing shared-ID removal
owns the children and parent. Original clearing copy constructor423570 and
GetInteger/SetInteger execute in the oracle rather than being simulated.

`ExecuteCommandEffectEthereal140519e10..140519efa` produces type63 with
INTs `[8,28,0,0,0,0]`, subtype8 and the caster creator. It uses the existing
`OnApplySanctuary431120`/`OnRemoveSanctuary437ff0` implementation: no-save
visibility blocking, pacification, module invisible-ID membership and icon107.
There is no separate guessed ethereal state or spell-ID branch.

The installed goblin's `nw_c2_defaultb` SpellCastAt callback exposed an unbound
`ClearPersonalReputation`. `ExecuteCommandPersonalReputationAccess537e50..537fe5`
is now ported for ClearPersonalReputation and SetIsTemporaryFriend/Enemy/Neutral.
It pops the owner before the optional target (default self only in native
execution context1), optional decay0 and FLOAT duration180. It clears once,
queries the target even though that result is unused, and for the three setters
clears a second time before adding. Neutral appends -100 then50 as two records.
The existing native-traced clear3d3680/add3d0c50 owners perform mutations; no
direct faction replacement or list merging. This local VM uses game-object
execution context1, consistent with its existing script casting adapter; the
pure boundary also covers other context values without inventing a self ID.

REA dossiers are `rea-effect-complex-command-current`, `rea-curse-apply-owner`,
`rea-curse-remove-owner`, `rea-effect-ethereal-command`, and
`rea-personal-reputation-vm-wrapper` under `backups/animations`. Full Curse
assembly and bounded function ranges are retained alongside them.

## Validation and limits

`native-curse-effects-observations.json`:662 complete original-code cases,
including756 executions of the original copy constructor. Covers loading/dead,
duration0..4, noncreatures, plot, immunity/bypass, absent creator, signed values,
icon inheritance, constructor defaults and VM failures. Allocation/base ctor,
VM scalars, lookup/casts, lower immunity/feedback, ApplyEffect and AI insertion
are captured boundaries. The first oracle run failed from incorrectly captured
stack offsets for AddEventDeltaTime; v2 corrects Windows x64 callee offsets and
passes. No failed capture is counted as validation.

`native-personal-reputation-command-observations.json`:580 complete original
wrapper cases covering four ordinals, arity1..4, context0/1/2, absent owners,
decay flags, signed fractional durations, pop failures and exact mutation order.
Lower lookup/clear/add remain captured boundaries, separately implemented by
existing native-traced code. The two new test files compare all1242 native cases.

`installed-curse-ethereal-v9.json` PASS: installed Prelude and unchanged cleric
BIC; real NCS constructors/apply, actual ability caches, deferred CON/event5,
all six score changes and restoration, shared-ID icon cleanup, and Ethereal
visibility/pacification. Native cheat-cast actions execute untouched Bestow Curse
and Ethereal impact scripts (active rows4/443), with real saving throws/RNG and
the goblin's SpellCastAt callback. Both produce their parent on seed1. Canonical
object allocation cursor is unchanged. These IDs are fixture observations only.

Earlier installed probes are retained. Self-target Bestow Curse reaches the
installed script but its friendly-target branch produces no curse. A training
dummy lacks the authored visibility state needed by ordinary targeting. The
accepted probe uses a visible hostile goblin; observer attack/perception and
caster visibility are deterministic fixture inputs, periodic AI/startup disabled,
and area-entry queued events discarded. This is not whole campaign acceptance.
One absent `plc_w02.pwk` load is explicitly retained separately from new errors;
the accepted probe has zero new errors. It does not fabricate that missing asset.

All1898 tests and production build pass. Existing Sanctuary actual right-click
self wheel, prepared-slot consumption, release and icon/effect pool UI regression
passes (`curse-ethereal-sanctuary-ui-v1.txt`). This is shared-owner/UI regression,
not rendered acceptance of every new spell, class, hotbar or transport variant.
The production bundle-size advisory remains.

Active-data auditv48:840 spell rows,618 impact-script names,596 loaded,
65 unbound commands/22 missing scripts. Auditv49:62 unbound/22 missing.
Binding presence proves availability only, not all branches or complete spells.
Unbound ModifyAttacks/Entangle and many other effect/casting/visual owners remain;
combat and the full base campaign remain unfinished. The goal stays active.

Verified checkpoint: `backups/curse-ethereal-1898-20261017-v1.zip`,10011files,
129424168bytes; every archived entry length/SHA256 verified. Process45799
completed with exit0. Final full tests25651/buildv2 terminal PASS. These
verification notes were added after sealing the checkpoint.
