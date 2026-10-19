# Time Stop effect construction, overlap and cleanup

Target: NWN:EE89.8193.37-17 x64, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The previous goal turn made concrete progress on shared native event timing and
sealed its verified1941-test checkpoint. This turn connects Time Stop's engine
effect owners to those clocks; the complete goal remains ACTIVE.

## Native findings

REA dossiers `backups/animations/rea-time-stop-*-owner.json` contain original
procedure ranges, callers/callees and pseudocode. Isolated original-code oracle
`scripts/inspect-native-time-stop.py` executes the complete owners below and
native seconds conversions/AddWorldTimes/SetExpiryTime. VM/base allocation,
server pause/exclusion/getters and creature/DM queries are captured boundaries;
the corresponding pause/clock/event owners were independently compared in prior
increments. This oracle is not a full native process, script VM or renderer.

| Owner | Address | Behavior |
| --- | --- | --- |
| ExecuteCommandEffectComplex, ordinal467 | `1405180b0` | EffectTimeStop creates native64, subtype8, duration-kind0, eight zero INTs; tags creator. VM push failure returns-638. |
| OnApplyTimestop | `140434810` | Pause0: add target to exclusion mask1, toggle1, retain. Otherwise query pause again. Exact1 recomputes first existing64 deadline from target ACTIVE time plus incoming duration, consumes incoming. No existing64 retains incoming. Other pause values retain without adding/toggling. |
| OnRemoveTimestop | `140439240` | Toggle1 unconditionally; scan sorted effects through98. Any98 preserves exclusion; otherwise remove mask1. Another64 does not preserve it. |
| OnApplyTimeStopImmunity | `1404347e0` | Add target to exclusion mask1, retain. |
| OnRemoveTimeStopImmunity | `1404391b0` | Sorted scan through98; another98 by pointer preserves exclusion. Otherwise creature with nonzero native DM INT preserves it; else remove mask1. |

Loading, dead/plot state, creature casting and duration kind are not admission
gates in these four effect handlers. Apply's64 search scans the whole live array,
even past higher types; remove's98 search stops at the first higher type. These
differences and the second pause query are preserved. Recasting modifies only
the first retained effect's expiry fields; it does not replace duration, ID,
creator, spell ID or other payload. The initial retained effect receives its
deadline through the already-mapped generic ApplyEffect world-time capture.

Apply ignores an AddWorldTimes failure. If it then finds64, it passes unwritten
stack outputs to SetExpiryTime. The oracle demonstrates seededA5A5A5A5 outputs.
The port explicitly throws an unwritten-expiry diagnostic rather than inventing
a valid date; without a matching64 the unused invalid result still returns0.
This remains an explicit undefined-memory guard, not deterministic native parity.

Confirmed thin wrapper targets: add55afe0, pause query55b2b0, active timer55b2c0,
world timer55ba10, remove55bdc0, toggle55c270, DM query402f80. Wrapper55c270 was
separately inspected in `rea-time-stop-pause-callee.json`; it forwards to the
previously mapped internal TogglePauseState56ded0.

## Implementation

`src/time_stop_effect.js` contains the native effect64/98 methods.
`EffectRuntime` binds their retain/consume/remove results to its sorted owned
effect list. Providers use the canonical registry target ID, real server
exclusion lists, all three native clocks and shared pause/reprocess owner.
`ModuleSession.commands.EffectTimeStop` is the ordinary engine constructor.
There is no new public immunity constructor invented for internal effect98.
The installed spell's NCS script determines duration and associated effects.
No spell outcome, dice result or campaign behavior is implemented in a bespoke
spell-ID branch. Spellbook, hotbar and radial use the existing generic pipeline.

## Validation

`native-time-stop-observations.json`:2057 original-code cases,1923apply,
64remove,4immunity-apply,64immunity-remove,2constructor. Includes changed second
pause results, masks0/1/2/3, loading, float precision, day/DWORD carry, duplicate
and unsorted effects, pointer identity, creature/non-creature and raw DM values,
and two invalid-time adds. The constructor's base initialization is captured;
its native dispatch/type/subtype writes execute. JavaScript compares returned
constructor fields; allocation/VM push failure handling remains captured native
VM evidence, not simulated allocator failure in the application.

Oraclev1 stopped at an unrecognized thin-wrapper symbol; confirmed callees
replaced ambiguous export lookup. V2 revealed that its base-constructor stub had
retained incoming fixture flags; v3 explicitly zeros base storage. Accepted
capturev3 and logs are retained, rather than porting the contaminated duration
kind. Native and runtime focused tests4PASS. Runtime tests cover merged ID/
deadline, strict expiry, world restoration, immunity duplicates/DM preservation,
cleanup and admission during a higher-priority pause.

Installed `scripts/probe-installed-time-stop.mjs`, acceptedv4: three checksPASS:

- Ordinary player cast consumes the imported ninth-level prepared slot and runs
  installed `NW_S0_TimeStop` NCS; its authored d4 computation produces duration.
- Ordinary Light cantrip casts through the active action clock and installed
  impact NCS while Time Stop remains active and world time stays frozen.
- Full selected native creature frames advance the caster100ms while an ordinary
  NPC receives0 elapsed; natural effect expiry resumes world at the original
  timestamp and deferred authored events drain. Canonical references/ID cursor
  unchanged; no queued events left after settlement.

Fixture: owned in-memory wizard BIC changes class15 to17, supplies matching level
history length, raises INT to at least19 and imports active ninth-level known/
prepared spell. This is spell integration, not legal character creator/level-up
validation. Installed files remain read-only. Startup/general AI traversal are
isolated; actual individual player/NPC native frames run. V1 correctly rejected
missing level history; v2 exposed the fixture's unticked NPC carrying its pre-stop
conjuring interval. V3 consumes that interval before asserting frozen subsequent
frames; v4 additionally casts Light. Earlier failures retained. Runtime warnings
are retained:2trap omissions,2incomplete pause notifications,71queue-clock local
recovery occurrences; no runtime errors. No unsupported calls were suppressed.

Electron `--time-stop` UIv2PASS, terminal0: active spellbook drag to native hotbar
intParam185, right-click self Cast spell/Wizard/Levels7–9/Time Stop, ordinary cast,
authored effects, physical prepared-slot consumption, natural full-native-AI
expiry, unchanged canonical player ID. Active/expired screenshots inspected/
retained. UIv1 fixture used an incorrect quickbar field; v2 asserts intParam and
the existing Cast spell menu label. No console or new runtime errors; all warnings
retained, including baseline lifecycle/trap/presentation omissions and repeated
queue-clock recovery. Native AI is on here; startup/entry position are fixtures.

Full suite1945PASS (`time-stop-full-tests-v1.txt`), terminal0. Buildv1PASS with
existing bundle-size warning. Final normal casting UIv1PASS, terminal0:
spellbook, self radial, slot consumption, F2 target/cancel, casting animations and
world radial Counterspell target22. Static active spell auditv52 now57unbound commands,
22missing impact scripts,840spell rows/618names/596loaded. Audit exits1 for those
recorded missing scripts; it is not a clean ecosystem pass. Binding presence
does not establish all branches or all spell forms.

## Remaining work

Time Stop's core effect lifecycle and ordinary/UI casting are now connected.
Full native client pause notification/visual freeze, additional periodic owners
and non-creature ResetUpdateTimes remain incomplete. No renderer-freeze parity
is claimed from screenshots or logical clock tests. Repeated undefined GUI-clock
recovery diagnostics need follow-up; their current behavior remains the explicitly
documented local recovery policy. Generic ApplyEffect bookkeeping, saved active
effects, the remaining engine calls/scripts, combat and campaign acceptance remain
open. Single-player remains the priority; the full goal stays ACTIVE.

Verified checkpoint: `backups/time-stop-effects-1945-20261017-v1.zip`,
10450files/140405765bytes. Every archived length/SHA256 verified;
session81543 terminal exit0 consumed. Verification note added after sealing.
