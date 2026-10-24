# Multiplayer area-transition render recovery — 2026-10-19

Target NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original install and running vanilla server20964 remain unchanged.

## Observed failure

Sealed local-network-progression-v106.json contains native4/1 entries for
m0q1a (9tiles,0x80000001) and m0q1b (100tiles,0x80000025). The backend
reached generation2, areaReady true. At05:40:50.792Z a runtime.uncaught
exception in nativeCosf -> stepClientFacing -> NetworkMotion.update ->
NetworkScene.update interrupted Three's animation callback. The trigonometric
input guard rejected angles above32 even though normal elapsed world time can
produce larger turns after a load stall. An earlier QA door request failure
had also stopped passive sampling; this is a harness defect, not evidence
that the server failed to send an area. That sampler now retains its first
input failure while continuing observations.

## Original-code evidence and fix

REA rea-transition-cosf.json covers cosf140c7ac70..140c7b16f. SSE compare
140c7acf5 reads double constant140ed0580 (0x411e848000000000 =500000).
Below that boundary the existing inline quadrant reduction/polynomial applies;
the FMA branch has a wider bound. The replacement now accepts the common
finite domain abs(input)<500000. It does not clamp elapsed time, guess a local
position or substitute an unverified host trigonometric function. Both CPU
paths still evaluate and diagnose any different float32 output. Larger
remainder helpers and CRT floating exception/errno state remain unimplemented.

inspect-native-network-facing.py --stalls executes complete807690 plus its
original vector and SSE CRT helpers.96cases span idle/combat/run facing,
four target directions and elapsed1s..80000000ms. All match the replacement's
orientation/target within2e-6 and exactly match animation requests. Original
1176normal facing cases still pass.

NetworkMotion catches an unavailable facing branch per actor, reports its
object ID and elapsed time once per repeated failure, retains displayed
facing and retries next frame. Remaining actors and the render loop continue.
Canonical server state is untouched. Scene snapshots now include area ID,
resource reference and attachment state to distinguish stale telemetry from
a missing transfer.

## Validation

51focused tests,249network regression tests and buildv2 pass. The added real
v106 replay detaches/disposes the old root, retains the controlled proxy's
identity and transmitted entry pose, loads all100destination tiles, excludes
old-area bindings and survives25s frames followed by normal frames.

Corrected live v107 opened the server-unlocked door after normal Pavel/Bim
dialogue. The subsequent native transfer reached attached m0q1b,100tiles,
playing/generation2, same controlled0xffffffff at transmitted entry position.
No runtime.uncaught or scene-facing-unavailable was recorded. The user
confirmed closing/disconnecting this client; its full report is sealed.
Only one post-load destination sample was captured before closure, so this
is not a longer campaign gameplay acceptance. Area/shader preparation still
has a noticeable delay (~24s in this run). A user floor click during loading
was rejected by the existing backend readiness guard. No original-client
coexistence or full multiplayer completion is claimed.

Frozen summary: network-area-transition-acceptance-v1.json. Latest previous
verified checkpoint: multiplayer-containers-20261019-v1.zip. This fix and
preceding speech/page work are included in the server-speech checkpoint;
verify the writer result and independent scope audit before calling it saved.

SEALED checkpoint multiplayer-server-speech-20261019-v1.zip:14620files/407536480bytes; writer completed with exit0 and every archived length/SHA256 verified. Independent audit14621entries/76required/0missing/0forbidden/0duplicates/0new credential candidates (96changed/new text files scanned). This post-seal note and audit are outside the archive. Replacement v107 was closed by user; server20964 unchanged. Full multiplayer goal remains active.

