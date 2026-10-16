# Shared appear effect and action, October15,2026

NWN:EE89.8193.37-17; unchanged original nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Source:appear_effect.js plus VM/EffectRuntime/action dispatcher bindings.
No game assets or binaries copied; no Ghidra edits.

EffectAppear482/140517750..14051782d creates internal81, subtype0, tags
creator, writes raw animation INT0 (default1). OnApplyAppear1404272c0 always
returns consumed1; for creatures it resolves AsCreature, clears actions and
adds animation95 when INT0==2, otherwise63. Loading is ignored by this owner.
The effect is not retained on the creature. Noncreatures receive no action.

AddAppearActions14037d090 returns0 only when commandability+ec==0. Otherwise
it queues action52 at the back with a new native group and INT animation,
then SetGroupInterruptable14049aff0 sets every matching group's9c to0.
The shared action list now provides that group mutation. The new action
cannot be cancelled by ClearAllActions. ClearAction52 follows the existing
common lock/timestamp tail when9c is nonzero and returns0 immediately if zero.

AIActionAppear body1403ac703..1403ac7d0 uses raw parameter0, or63 when parameter
count is zero, and the native world-time subtraction. Its millisecond remainder
alone gates a fixed2000ms duration. Before that threshold it sets speedDC=1,
sets the requested animation and returns1. Afterward it restores speed/idle1
for creatures and returns2. This is independent of MDL clip duration. Invalid
time-subtraction scratch state remains diagnosed rather than synthesized.

Native GetScriptEffectType140423fe0 is already captured in
native-effect-script-type-observations-v3.json:81 maps0 normally and91 only
when allTypes!=0. Summon6 similarly maps0/100. Public query bindings now retain
both hidden-type mappings; script enumeration still respects exposed flags.

inspect-native-appear.py executes unchanged constructors/apply/queue and the
profiling-disabled action body, plus full ClearAction52. It captures lower VM,
base allocation, action-list transport, timer and virtual setters; it is not
an original-process encounter.142 cases:10 constructor,40 apply,8 queue,
72 action,12 clear. Boundaries include exact1999/2000ms transition, raw IDs,
missing parameters, commandability and cancellation flags/head semantics.
Focused tests:appear-focused-v1.txt. All1355 tests/build pass:
appear-full-tests-v1.txt/appear-build-v1.txt.

probe-live-appear.mjs imports installed wizard.bic into the canonical session.
Raw animation arguments-1/1/2/99 select63/63/95/63. Each clears the prior action,
queues uninterruptible52, survives cancellation, runs through the native action
timer for2000ms from its first traversal (2100ms with100ms fixture ticks), then
finishes at idle/speed1 with no retained81 or new diagnostics. Noncommandability
preserves the previous queue. Hidden GetEffectType queries match0/91.
Reports:live-appear-v1.txt/live-appear.json. Startup/general AI disabled; actual
rendered clip/pose, independent original-client and network acceptance are not
claimed by this fixture. The existing renderer uses canonical base animation
through its independently mapped native name/MDL bindings.

Summon event24 can use this shared effect once its remaining ownership and
destruction providers are connected. Full spells, combat and continuous base
campaign acceptance remain unfinished; active diagnostics must stay enabled.
