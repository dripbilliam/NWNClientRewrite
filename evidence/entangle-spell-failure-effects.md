# Entangle, spell failure and on-hit miss chance — 2026-10-17

Later update: [native combat-information rebuild](combat-information-refresh.md)
connects the synchronous arcane/resistance refresh that was still missing below.
The original validation/limits remain historical evidence, not current omissions.

Read-only NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project unchanged. Installed NCS and active 2DA
select behavior; no runtime branches for the example spells were added.
Single-player is the current acceptance priority. Multiplayer remains unproven.

## Native owners

Entangle constructor ordinal130 in ExecuteCommandEffectComplex1405180b0
produces18/subtype8. OnApplyEntangled14042d5d0..14042d943 gates loading/death
except duration3/4, then immunity10 before plot (feedback144 on immunity).
Accepted creatures clear actions and preallocate THREE clearing copies before
applying attack decrease11 [2,0,28], DEX decrease37 [1,4], state23 [-3]. The
last child clears movement permission bit2. A separate clearing copy adds
icon5. Exposed effects emit floaty2237, including noncreatures. Shared uint64
IDs retain existing linked removal semantics. Removal140436c20..140436c77
refreshes NPC visible lists unless possessed.

SpellFailure ctor14051b940..14051bb36, ordinal690, always pops amount/school;
optional third argument selects school failure92(mode0) or arcane25(mode1).
Other modes leave a fresh invalid effect; no constructor magnitude clamp.
School apply140433700..1404338ed sums matching RAW school selectors in sorted
type92 records, wraps signed DWORDs, clamps0..100, writes the nine-school cache
through SetSpellFailure416ae0, dirties53c and adds icon110. Setter narrows school
to BYTE before checking<9: raw256 compares separately but writes school0.
Remove140438920..140438a7c excludes ALL records sharing the removed uint64 ID.

Arcane apply140427330..140427401 adds incoming magnitude to signed BYTE D78
with DWORD wrap, clamps[-100,100] and writes the BYTE cache. Removal
140435db0..140435ea9 recomputes sorted type25, excluding exact POINTER rather
than effect ID; null removal resets cache. SetArcaneSpellFailure415250 tailcalls
UpdateCombatInformation4171e0. Cache write is connected; synchronous full combat
refresh is STILL unimplemented and explicitly diagnosed in the live runtime.

MissChance ctor14051a5d0..14051a729, ordinal477, accepts1..100, produces75/8.
Public kind1 maps to stored2, kind2 to3, others to0; invalid magnitudes produce
a fresh invalid effect. Existing vision/combat-defense owners consume records
on the ATTACKER.

Installed on-hit testing exposed missing type94 application. Complete
OnApplyCutsceneImmobile1404286b0..140428734 always makes one clearing copy,
writes state23 INT0=-3, applies with caller loading value; no admission gates.
Native InitializeEffects registration has NULL remove94, so shared-ID state
child owns restoration. Existing ctor767/type94 now has native comparison too.

Ports: src/entangle_effect.js, src/spell_failure_effect.js, VM bindings and effect
runtime routing. Full REA dossiers retain bodies/call sites/dependencies:
entangled-apply-owner, entangled-remove-owner, spell-failure-command,
spell-failure-apply-owner, spell-failure-remove-owner, misschance-command,
arcane-failure-apply-owner, arcane-failure-remove-owner, spell-failure-setter,
arcane-failure-setter and cutscene-immobile-apply-owner.

## Validation and limits

inspect-native-entangle-effect.py:1373 cases/884 real clearing copy executions,
including64 immobilize combinations and two ctor767 outcomes. Spell-failure
oracle:1255 cases/194 real copies, original scalar accessors and both cache
setters. **2628 total cases** compare ordered calls, metadata, returns and bytes.
VM/allocation/feedback/child dispatch/synchronous refresh are captured lower
boundaries; this does not prove those complete subsystems. Initial failure
oracle incorrectly stubbed security-cookie checking and clobbered EAX. Accepted
v2 executes original verified success instructions140c10410..140c10427.
Failed REA boundary and rejected external failure-tail CFG remain retained;
neither is treated as complete function coverage.

Installed Prelude/wizard probe **v14 passes eight checks**:

- NCS Entangle blocks actual movement input; removal restores movement/icon.
- School failure stacks/caps/recomputes; school9 leaves cache unchanged.
- Arcane failure stores signed deltas and recomputes on removal.
- Real prepared release fails/consumes slot/skips impact; removal allows the
  next prepared cast to consume a slot and run untouched installed NCS.
- NCS100% miss chance reaches real combat defense result9.
- Untouched Web Bolt ordinary cast on a LIVING goblin retains18 and children.
- Untouched NPC antimagic cone retains school failure on PC.
- Installed Chaos Shield on-hit script runs through NCS property constructor,
  addition, real payload/melee signal/event19. Retains miss50/kind3 plus94/23;
  cleanup restores movement/removes property. Canonical object cursor unchanged.

Controlled fixtures: startup/periodic AI off; Web/cone positions and visibility
supplied; successful zero-damage on-hit strike supplied; deterministic local RNG.
Full native RNG draw order unproven. Failed v1..13 retained, including missing
item context, live Web touch miss and genuine unsupported94 error fixed above.
v12 first passed with a Web victim killed by an earlier cast; v14 uses a living
target. v14 has zero new errors, seven retained cache/corpse/presentation
diagnostics. Any exact known plc_w02.pwk absence remains separately recorded;
v14 did not emit it during its checks. No clean whole-area/campaign claim.

1902/1902 tests and production build pass (existing chunk warning). Offscreen
UI passes spellbook click, self radial, slots, F2 targeting, animations, cancel
and counterspell radial; exits0, post-PASS GPU shutdown stderr retained. This
verifies shared casting regression, not all new effect visuals. Auditv51:
840 rows/618 impact names/596 loaded/58 unbound commands/22 missing scripts.
Binding presence does not establish branch completeness.

Whole spells/combat/campaign remain incomplete. Continue generic effect and
casting owners plus campaign blockers, including full synchronous combat-cache
refresh; retain durable diagnostics instead of substituting spell-specific code.

Verified checkpoint: backups/entangle-failure-1902-20261017-v1.zip,
10128 files/130989513 bytes; all archived lengths/SHA256 verified, exit0.
This verification note was added after sealing; the archive retains the
pre-verification notes and all code/captures used for these checks.
