# Native effect deadlines and player queue recovery — 2026-10-17

Read-only original NWN:EE89.8193.37-17 x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install/Ghidra project unchanged. Previous goal turn made verified
progress: native pause clocks, independent comparisons, live failure reproduction
and sealed backup. This continues the full spell/combat/campaign goal.

## Player queue result

The last checkpoint reproduced a player frame abort after pause-clock rebasing.
`inspect-native-player-queue-clock.py` now executes the original cadence block
14037c8df..14037c951 and complete SubtractWorldTimes140597a20, varying144 inputs
and caller scratch seeds. Defined cases use inclusive300ms, commit stamps after
GUI update and ignore elapsed days. Backwards valid times leave the subtraction
outputs unwritten. With scratch0/299 the original skips GUI work; with300/FFFFFFFF
it runs GUI work and commits. Neither outcome is a deterministic consequence of
the clock inputs. Timer lookup/time and queue display are captured boundaries;
the complete caller stack/prologue is not reconstructed by this fixture.

The client now explicitly reports `combat.queue-clock-undefined`, retains the
existing GUI queue/stamp for that unavailable decision and continues subsequent
skill/stat/AI-level work. It never supplies elapsed0 or changes the saved stamp
to force success. This is a **declared local recovery policy for an undefined
native result**, not proof of matching a particular native stack-garbage branch.
Missing recovery providers still fail explicitly. Original-defined cadence paths
are compared directly; recovery assertions are labelled separately.

Installed player probev3/v4 PASS: after clock reset the queue stamp stays
day461132/time1561234, a real applied attack buff's dirty combat cache still
rebuilds, removal restores it, and advancing normal clocks resumes the queue at
time1562100. A single undefined-clock diagnostic and all pause/trap warnings are
retained. No canonical object reference/ID allocation changes. The historical
v1 failure report remains. Startup/general AI are disabled in this fixture.

## Effect deadline owners

`src/effect_clock.js` ports the expiry portion of ApplyEffect14048e68b..14048e739:
after an admitted OnEffectApplied callback, duration low3bits1 with loading
exact0 converts FLOAT seconds and adds them to **WORLD time captured before the
handler**. Loading preserves stored expiryDay/expiryTime. SetExpiryTime1404251f0
stores canonical DWORD day/time fields. It does not use host scheduler time.

The common UpdateEffectList14049e04a..14049e0b8 expiry decision checks the caller's
captured frame time against that deadline, removing only on exact native
CompareWorldTimes result1. Equality retains the effect; invalid comparisons
are not treated as expired. The enclosing native owner selects an active timer
for arithmetic; the creature frame supplies its previously captured active time.

EffectRuntime now captures world time before apply dispatch and initializes
retained deadlines after the handler. Linked children keep their independently
captured deadlines; a consuming parent wrapper does not overwrite them. A weak
ownership set avoids re-finalizing records without adding fake serialized
fields. Deferred polymorph reversal uses its actual native500ms day/time expiry.
All runtime `expires` scheduler-millisecond fields and comparisons were removed.

Creature frames pass captured time into effect updates. Regeneration and
poison/disease polling use that time too, retaining their previously mapped
native tick rules. Generic temporary expiry writes the same pass-local pair
that a later failed regeneration subtraction leaves untouched, preserving the
native shared scratch behavior. This is not a complete port of all other
periodic branches or the full ApplyEffect admission/attribute/retention owner.

## Independent comparisons and tests

`inspect-native-effect-clock.py` executes1360 cases:1080 initialization and280
expiry predicates. Original bounded owner instructions, FLOAT day/time conversion,
world-time add/compare and expiry setter/getter execute unchanged. Timer lookup
and removal dispatch are captured boundaries. Durations include fractional,
negative, zero and multi-day values; cases include raw duration masks, loading
flags, day overflow, invalid comparisons and null effect predicates.

Initial expiry fixture placed its saved timer pointer in an argument slot;
native argument writes clobbered it. Corrected frame separation in nativev2
passes. The failure/testv1 logs remain. Four additional runtime/native effect
tests and two queue-clock tests bring the full suite to **1935/1935 PASS**
(full-testsv3). Buildv2 PASS with existing bundle-size warning. Runtime tests
also check pre-handler clock mutation, independent linked-child deadlines,
excluded versus world clocks, exact expiry and loading deadline preservation.

First full-suitev1 had10 failures in legacy fixtures that advanced scheduler
milliseconds without snapshotting the world clock. Those fixtures now follow
the host snapshot boundary; their original expiry/cleanup assertions remain.
Deferred-removal fixtures set native expiry fields instead of synthetic host
millisecond fields. No native expiry test was relaxed to satisfy wall time.
Probe-only advance-effect-clock.mjs advances/snapshots real clocks; its deadline
advance explicitly requires an unpaused session. It is not engine timing code.

## Installed and rendered checks

Installed effect-clockv2 PASS through actual NCS command execution:

- A controlled10HP injury and EffectRegenerate2/0.25s tick strictly after250ms
  on the excluded creature's advancing clock while world remains fixed.
- Attack buffs retain at exact1000ms, expire on excluded clock1001ms and remain
  on the ordinary creature while its world clock is frozen.
- After world resumes, the ordinary creature retains/loses the same buff at its
  original exact/strictly-after deadline. Canonical references/cursor unchanged.

These are explicit pause/exclusion fixtures with startup/general AI disabled,
not a Time Stop cast. All diagnostics retained; no engine errors in these checks.

Installed equipped-items/regenerationv1 PASS checks enhancement, six abilities,
damage, light and regeneration with canonical ownership, expiry and gear cleanup.
Authored Magic Vestmentv2 PASS uses its installed impact script, canonical worn
item, native AC and linked icon35, exact expiry and restored AC8. Item mutationv3
PASS covers queued removal, deadline expiry and actual equipped attack-property
children cleanup. Its absent-setting guard is an explicit temporary removal of
host setting134, restored afterward; no unavailable materializer is claimed.

Two old probe assumptions were corrected after retained failures: armor now
has its native linked icon, so type48 alone was incomplete; item attack
materialization/normal host setting have been implemented since the old probe.
The guard test initially passed a synchronous throwing call directly into
assert.rejects; v3 fixes its async wrapper. Those are fixture corrections, not
engine behavior changes to hide a failure. Six installed summon lifecycle
cycles PASS, including actual authored spell expiry and item destruction.

Electron polymorph-hotbar UIv1 PASS: F2 parent cast, slot use, authored form,
model/animation rebind and deferred radial restoration. Final default UIv1 PASS:
spellbook, self radial, slot use, F2 target/cancel, live casting animations and
world-radial Counterspell with canonical target22. Console/casting-phase failures
are empty where asserted; baseline diagnostics and startup/entry fixtures remain.

## Remaining goal work

Time Stop64/immunity98 handlers are researched but still unbound. Native delayed
event queues/clock selection, other periodic owners and full pause notification/
client presentation remain prerequisites. The queue fallback is explicitly not
native undefined-memory parity. Full generic ApplyEffect, saved active effects,
remaining spell engine calls, combat and campaign completion remain open. Latest
static spell audit remains58unbound/22missing impact scripts (binding presence
does not establish branch coverage). No spell or campaign outcomes were
hardcoded. Goal stays ACTIVE; single-player remains first.

Verified checkpoint: `backups/native-effect-clocks-1935-20261017-v1.zip`,
10391files/137731693bytes. Every archived length/SHA256 verified;
session6105 terminal exit0 consumed. Verification note added after sealing.
