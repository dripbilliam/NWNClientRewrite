# Server pause and Time Stop clock prerequisites — 2026-10-17

Read-only original NWN:EE89.8193.37-17 x64 nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No original installation or Ghidra project edits. Previous goal turn was
verified progress: combat-cache/polymorph ownership code, native comparisons,
installed/UI checks and sealed backup. Single-player spellcasting, combat and
campaign completion remain the full active goal.

## Native pause owners

`src/server_pause.js` ports complete SetPauseState14056bd40..14056bf70,
TogglePauseState14056ded0..14056dee4, AddToExclusionList14055d010..14055d089,
RemoveFromExclusionList140569c70..140569d18,
IsOnActiveExclusionList140564530..140564580,
ReprocessExclusionListActions14056a270..14056a441 and creature
ResetUpdateTimes14039f0d0..14039f0f7. Active timer selection already ported
GetActiveTimer14055f0d0..14055f195 and is now connected to real clocks.
GetActivePauseState14055f0b0 is independently mapped in a retained dossier.

Bit2 takes active-timer/exclusion priority. Add prefers bit2 for combined masks,
whereas remove prefers bit1. IDs remain canonical unsigned values; insertion
rejects duplicates and removal erases the first match. A null active exclusion
list admits an object; this is distinct from the ordinary equipment exclusion
query. OBJECT_INVALID always selects world time. JS arrays own the ID lists;
native allocation addresses/capacities are captured lower boundaries here.

SetPauseState compares the current BOOL against the raw enabled INT. Exact1
sets mask bits and pauses world time, and also timer1 when bit2 is active.
Other values clear bits unless the initial BOOL comparison already returns.
The mask1/mask2 OFF branches have different pause/reprocess/reset/snapshot/
previous-counter/unpause order. Combined/unknown masks are not silently
normalized to those branches. Reprocessing sees **post-clear flags**, queries
the selected timer before canonical object lookup, iterates live list length
and calls each surviving object's virtual ResetUpdateTimes.

Creature ResetUpdateTimes updates only heartbeat54c/550, perception578/57c and
last framebc/c0. It does not reset queue594/598 or spawn548. No extra fields
were added to make a test pass. `WorldTimer.reset` follows the complete
ResetTimer1405977e0..14059782b field copy, retaining the destination's host tick
provider and never copying fabricated padding.

## Session integration and explicit limits

ModuleSession owns world, timestop(timer1) and pause(timer2) clocks. Native
LoadModuleStart140480cd6/140480d04 resets the latter two from world time after
calendar loading. Host updates snapshot all three with the same monotonic
scheduler tick source. Creature frames select their actual active timer;
the PC action-queue clock uses GetPauseTimer14055b870 -> internal100a8.
The old independent nativeActivePauseFlags adapter now aliases the canonical
server pause flag byte. Module sanity checks use the real exclusion storage
and can clear an orphaned bit1 pause through the native transition owner.

Local host pause notifications currently broadcast typed mask/value events.
Native sender1404dd0c0 also encodes active exclusions and filters player load
state; its full codec/client presentation is mapped but not ported. Every
local transition records `server.pause-session-incomplete`, retaining this
missing integration together with effect/event clock and player queue gaps.
Non-creature ResetUpdateTimes remains an explicit unsupported branch.

**Time Stop casting is not enabled by this checkpoint.** Effect64 handlers
apply434810/remove439240, immunity98 apply4347e0/remove4391b0, module sanity48a240
and the native notification sender are retained REA research, not effect
bindings. Ordinary effect expiry and periodic providers still use scheduler/
world clocks in several paths, and delayed events still use the host queue.
Those paths must be reconciled with native timer selection before claiming
the spell works. No cast result, duration or campaign exception is hardcoded.

## Independent validation and discovered blocker

**Follow-up:** [Effect clocks and queue recovery](effect-deadline-clocks.md)
records the explicit local GUI recovery, removes the frame abort and replaces
effect wall-time deadlines. The player probe now passes those scoped checks;
Time Stop/event/notification acceptance is still open. The following failure
description remains historical evidence of this1929 checkpoint.

`inspect-native-server-pause.py` executes1214 original-code cases:
152set,144toggle,270add,270remove,120active-exclusion,120active-timer,
128reprocess,9creature-reset and1fulltimer-reset. Original owner ranges come
from exact REA body metadata. Lower pause/unpause/snapshot operations, message
broadcast, object lookup/virtual calls, array addition and memmove are captured
boundaries. ResetTimer instructions execute within state changes and directly.
Cases cover raw flags/masks/BOOLs, post-reprocess flag mutation, null active
lists, duplicate IDs, high canonical IDs and list growth during reprocessing.
Native v1 fixture failed because eager construction of all mode arguments read
an absent day field; v2 corrected it. Failed log retained.

Six new tests compare order, final fields/counters, IDs/lists, selection,
live mutation and preserved host tick sources. Focused13tests PASS. Initial
full-suitev1 failed only an obsolete test expecting pause transitions to throw;
that integration test now verifies an orphaned stop is cleared and notified.
Final full-suitev3 **1929/1929 PASS**, buildv3 PASS (existing bundle-size warning).

Installed probev2 PASS three scoped checks: real NPC frame uses the advancing
exclusion clock (1234ms) while world stays fixed; nested bit2 pause freezes
timer1, selects timer2 for its exclusions and restores timer1 correctly; removing
the stop resets the three native creature time pairs before normal100ms frame
resumption. Canonical object references and allocation cursor stay unchanged.
Four incomplete-session warnings and one existing trap warning are retained.
Startup/general AI are disabled; these checks do not exercise a real cast.

The separate **player-frame probev1 FAILS**, retained as the next reproduction.
The hero updates its queue stamp to day461132/time1561234 during the stop. After
native clock rebasing, its next queue subtraction is backwards and the current
frame guard throws `Native action queue elapsed time is undefined after failed
subtraction`. Original AIUpdate14037c8df..14037c94c ignores the subtraction return
and reads stack output; native ResetUpdateTimes does not reset that queue stamp.
The failed original output is unwritten. Do not invent a timestamp reset, zero
elapsed or successful native queue branch without further caller/ABI evidence.
This probe's thrown error is persisted in its report, not declared a pass.

Final normal Electron polymorph-hotbar UIv2 PASS terminal0: F2 parent cast,
prepared-slot consumption, authored child script, form/model/animation rebind,
canonical ID and radial cancellation/restoration. No casting-phase or console
errors. Startup/entry fixtures and all diagnostics remain. This is a regression
check for normal clocks, not pause UI or campaign acceptance.

Next finish the player queue/caller scratch behavior, active effect/periodic
and event timelines, notification and effect64/98 bindings, then independently
test real Time Stop casting and expiry through the shared spell pipeline.
The wider58unbound/22missing-script audit, other spell/combat/campaign gates
remain incomplete. Goal stays ACTIVE.

Verified checkpoint: `backups/server-pause-clocks-1929-20261017-v1.zip`,
10338files/136548858bytes. Every archived length/SHA256 verified;
session76682 terminal exit0 consumed. Verification note added after sealing.
