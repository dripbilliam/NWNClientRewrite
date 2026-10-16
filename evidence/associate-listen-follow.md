# Authored associate commands and following — October 15, 2026

Target NWN:EE89.8193.37-17; nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. All native comparisons
execute read-only mapped instructions with recorded lower provider boundaries.

## Conversation/listen event

Creature event10/script7 body14038f623..14038f888 resolves associate3/client,
unpossesses that familiar when required, stores caller+1b8, pattern+1e8,
string0+1c8, integer2+1bc and integer3+1c0, clears previous owned captures and
copies strings1..integer0-1. The capture count includes the whole match, which is
not itself appended to the object's capture list. The expression parser's saved
captures and the object's received captures remain separate storage owners.

The original copies script slot7, substitutes NW_G0_Conversat only for empty
or exact lowercase `default`, then runs event7 unless the creature is a possessed
familiar and ALL_ASSOCIATES_RUN_SCRIPTS is0. The optimized native hash call
prehashes byte A (FNV seed af63fc4c860222ec) and consumes25-byte suffix
LL_ASSOCIATES_RUN_SCRIPTS; the complete key is ALL_ASSOCIATES_RUN_SCRIPTS.
Possession/unpossession remain explicit lower providers; possession itself is
not completed by this event implementation.

Matched-string owners ClearMatchedExpressionStrings140491060 and
AddMatchedExpressionString14048db90 release storage on clear and grow16/double
on append. VM17814052b6e0 returns empty for absent objects/types0..4/bad index;
VM17914052b860 reads count after lookup without the type gate. The replacement
diagnoses absent raw capture storage for non-CNWSObject owners instead of
inventing an area's field1f8. NWSObject constructor14048b8bb/c2 initializes the
separate capture allocation/count/capacity; destructor cleanup releases it.

inspect-native-listen-event.py records496 cases:240 event,4 clear,12 append,
240 VM-query cases. Native whole EventHandler, VM pop/push failure paths, C++
allocation failure, and lower script AI are outside these bounded comparisons.
Pseudocode falsely stops at the first free; complete assembly is authoritative.

## Force following

VM167 ExecuteCommandActionFollowObject14050dc60 appends55 then58 with independent
new groups, target/run1/distance/default flags0. It neither validates the target
nor checks commandability before queuing. Extra argc3 is retained although the
installed public API167 exposes two arguments. Float distance remains raw f32.

AIActionForceFollowObject1403beaa0 resolves target, casts it three times, samples
position and area, and inserts55/new group, wait30/same group/1second,
check-radius17/same group/range+maximum+LOS1, then movement/same group/15second
forced timeout. Actual front order is movement, radius, wait, follow. Missing
target/cast returns3. AIActionCheckForceFollowObject1403b1540 unconditionally
front-inserts58 then55/new groups and returns2. The old force-follow group never
silently becomes a future cycle's group. Native ClearAction1403870b0 cases55/58
use the shared interruptibility/orientation/timer tail, without attack cleanup.

inspect-native-force-follow.py records660 cases:144 command,432 follow,
36 check,48 cancellation. Action allocation/group mutation, movement queuing,
registry/casts and VM stack delivery are captured lower boundaries. Complete
existing movement owners execute in the live test; these comparisons alone do
not establish geometry, timed movement or native-process following.

## Movement timeout boundary

MoveToPoint1403c4071..1403c4134 constructs a separately owned CNWSForcedAction
(constructor140441b10), stores type1/group/area/point/target, converts seconds,
and queues **event18** (DAT140dfc188). Constant values are observed, not inferred
from neighboring constant addresses. Its caller requeues movement with force
cleared. Receiver14038f22d..14038f440 first CancelAction(0,group); only result1
and payload type1 construct jump5 (point) or48 (object) with the native argument
cells. A completed/cancelled old group produces no teleport. Shared cancel and
payload/jump-node ownership are connected. Forced JumpToPoint/JumpToObject
execution remains an explicit diagnosed lower owner; a stalled follow whose
group survives15seconds is therefore not yet fully supported.

inspect-native-forced-movement.py records102 bounded payload/receiver cases.
Seconds conversion and cancellation are independently compared existing owners;
jump execution and allocator cleanup are captured boundaries here.

## Installed-data and renderer checks

probe-live-associate-listen.mjs uses the installed wizard's real ready summon
spell, its authored impact/spawn scripts and the resulting nw_ch_ac4 conversation
handler. Follow(-5) creates55/58. Through the same local world-object update path
used by the client, the summon actually moves toward a relocated master and
stops near the scripted range4. Stand(-2), Guard(-7), Attack Nearest(-3), Heal
Me(-4) each reach the real conversation script and replace actions normally.
No enemy/healing outcome is claimed from this friendly-room fixture. The test
preserves full trace/diagnostics and only allows the known PlayVoiceChat error;
the latest v9 run reports no errors. Prior v8 reproduces the remaining voice
call, so zero errors in one RNG path does not prove voice support.

The owned-creature radial root now submits those original signed commands.
Startup/general AI are isolated in the engine probe; active test-character
world updates and authored scripts run. These are gameplay-owner tests, not a
campaign playthrough or unmodified-client/server comparison. Existing rendered
ground summon/owned Unsummon/model removal regression passes with0 renderer
errors after this change. Renderer listen-follow-summon-ui-v2.txt also verifies
actual world radial Follow and Stand Ground, canonical stored command/listen
state, then Unsummon and model removal; renderer errors0. All1,371 tests/build
pass. Static impact-script audit-v16 remains161 unbound calls/22 absent scripts:
these newly bound commands are exercised by associate AI, so that audit's scope
does not measure this milestone. Keep runtime diagnostics as additional evidence.

Subsequent [voice delivery](voice-quick-chat.md) connects PlayVoiceChat421,
installed cues and browser decode/start. The following was the research trail:
PlayVoiceChat421 routes through
ExecuteCommandVoiceChat14054b060 to SendServerToPlayerQuickChatMessage1404df1c0,
not directly to BroadcastVoiceChat. It substitutes OBJECT_INVALID with self and
narrows voice code to WORD; quick-chat sends family22/subtype0 to nearby same-area
players. Ghidra captures are saved. Client soundset/audio/text/animation delivery
and the stalled-movement jump owners still need reconstruction. Full associate
AI, all spell forms/effects, combat and campaign completion remain open.
