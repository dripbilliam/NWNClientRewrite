# Native AI event clocks and casting timer selection

Target: NWN:EE89.8193.37-17 x64, read-only original executable at
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Single-player remains the acceptance priority. This increment is progress toward
the active spellcasting/combat/campaign goal, not completion of those systems.

## Original owners and observed rules

REA dossiers `backups/animations/rea-pause-event-*-owner.json` retain the
original owners and exact procedure ranges. Original-code oracle
`scripts/inspect-native-ai-event-clock.py` executes these complete functions:

| Owner | Address | Observed behavior |
| --- | --- | --- |
| AddEventAbsoluteTime | `140556eb0` | Head scan; insert before a strictly later event. Equal timestamps retain insertion order. |
| AddEventAbsoluteTimeViaTail | `140556fb0` | Backward scan; insert after a strictly earlier event. Equal timestamps reverse insertion order. |
| AddEventDeltaTime | `1405570b0` | Read WORLD time, native AddWorldTimes; choose tail scan iff delta.time is nonzero. |
| EventPending | `140557fe0` | Native CompareWorldTimes result less than1 is due, including invalid result-2. |
| GetPendingEvent | `1405580d0` | Transfer first record fields/payload, clear original payload pointer and free event record. |
| UpdateState | `140559cf0` | Capture world time once for due-event traversal; no per-target active timer for queued deadlines. |

The original record has day/time DWORDs at0/4, caller/target IDs at8/C,
event ID at10 and payload pointer at18. AddDelta logs at native level1 when
GetActivePauseState returns exactly2 and either delta component is nonzero;
it still attempts the add. Invalid AddWorldTimes rejects before allocation.
Positive millisecond ties are LIFO. A whole-day delta with time0 is FIFO.
Raw millisecond deltas at/above day length reject; this owner does not normalize
them into days. Arithmetic and DWORD wrapping are native helper behavior.

`src/script_scheduler.js` now stores canonical IDs and native day/time deadlines,
uses those fields for insertion and delivery, and retains payload object identity.
`ModuleSession` supplies its shared cached world timer. Diagnostic standalone
schedulers own a real WorldTimer backed by their host clock. The read-only `due`
getter is a host-time projection for probes/debugging; it is never used by engine
ordering or delivery. Native AI still owns its full interleaved traversal; only
the separate diagnostic pump has a256-event cap. The pump also captures time once.

Combat and object lifecycle owners now pass explicit day/time deltas rather than
flattening them into host milliseconds. ModuleSession records paused additions
and rejected deltas durably as `scheduler.event-added-while-paused` and
`scheduler.native-add-delta-rejected`. Native pause warning is expected behavior,
not a hidden unsupported call.

Ordinary casting elapsed time and item casting timestamps now select the actor's
active timer. Their original action owners call GetActiveTimer at `14055b2c0`;
see existing original-code fixtures `scripts/inspect-native-cast-action.py` and
`scripts/inspect-native-item-cast-action.py`. Prior unconditional paused-casting
guards have been removed at these two already-mapped provider boundaries.
This does not change delayed events to use the caster's active clock.

## Validation

Original-code capture `native-ai-event-clock-observations.json`:786 cases,
36absolute/head,36tail,672delta,36pending,6pop. Native add/compare execute;
heap/list storage, world/pause getters and warning sink are captured boundaries.
Fixtures include duplicates, unsorted/invalid timestamps, wrap, high canonical
IDs and payload identity. Full payload destruction/AI dispatch/protocol are not
part of this oracle. JavaScript uses decoded owned DTOs and garbage collection,
not emulated native freed heap addresses.

New tests compare all786 cases and cover real NativeAIMaster traversal with
DelayCommand, saved NCS situations and SetLocalInt. Immediate and nested zero-delay
events deliver while world is frozen; positive delays hold even for an excluded
target, then deliver in native tie order after world resumes. Canonical object
references and ID cursor remain unchanged. A separate test covers callbacks
changing calendar time mid-pump. A casting-clock test covers ordinary/item
providers, both pause masks, priority and timer rebasing.

Installed Prelude/wizard probe `scripts/probe-installed-ai-event-clock.mjs`:
`installed-ai-event-clock-v1.json` PASS, two checks. Actual canonical player and
authored NPC, real DelayCommand/NCS/SetLocalInt dispatch, three session clocks,
world freeze/immediate event,100ms resumed deadline and LIFO order. Ordinary/item
casting providers select active vs world clocks correctly. General AI/startup are
isolated here; the separate runtime test covers actual native AI traversal.
This is an explicit pause fixture, not a full Time Stop cast. Four warnings
retained (two native paused-add warnings, two incomplete-pause notifications),
no runtime errors; all module load diagnostics retained separately.

Focused casting tests14PASS; previous queue/combat regressions35PASS. Full suite
`ai-event-clock-full-tests-v2.txt`:1941PASS, terminal0. Buildv1PASS, with existing
bundle-size warning. Electron casting UIv1PASS: spellbook click, self radial,
prepared-slot consumption, F2 targeting/cancellation, cast animations and world
radial Counterspell target22. Electron polymorph-hotbar UIv1PASS: authored F2
parent cast, live mesh/animation rebind, canonical ID and radial restoration.
Both terminal exit0; fixture scope and diagnostics retained in their captures.
Initial full-suite run had two obsolete positive-delay FIFO
and out-of-day millisecond fixtures. Corrected tie expectations to native LIFO;
the large exact-integer fixture now uses native BYTE-configurable255minutes/hour
so the intended delay fits the original day. Initial failure logs are retained.

## Remaining work

Time Stop64 and immunity98 handlers are researched but still unbound. Additional
periodic effect owners, full native pause notification/client presentation,
generic ApplyEffect bookkeeping and saved active-effect import remain open.
The latest static audit remains58unbound/22missing impact scripts; binding
presence is not branch completion. Original shared event ownership is now wired,
but complete spells/combat and campaign playthrough have not been established.
No spell-specific or campaign outcome was hardcoded. Goal remains ACTIVE.

Verified checkpoint: `backups/native-ai-event-clocks-1941-20261017-v1.zip`,
10418files/138622067bytes. Every archived length/SHA256 verified;
session1093 terminal exit0 consumed. Verification note added after sealing.
