# Timed native facing and the movement comparison recording

User supplied movementexample.mp4 (5.178s,2650x1080). Local Chromium file-origin
decoder extracted16 timestamped frames; movement-video-contact-v1.png inspected.
First decoder attempt used about:blank and could not read the local video;
file-origin v2 succeeded. This recording is a visual reference, not a packet
trace or an instrumented measurement of original-client frame timing.

Read-only NWN:EE89.8193.37-17 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binaries/Ghidra unchanged. Earlier movement distance, acceleration,
waypoint, correction and same-destination suppression remain in force.

## Confirmed discrepancy and native policy

NetworkMotion previously overwrote displayed orientation directly on a packet
and on every path waypoint. Native reader140781e80 stores normalized desired
orientation separately at2b4; client1408114d0 chooses path-direction2a8 while
moving, then calls140807690 each elapsed frame. The display direction44 is
distinct. Complete140807690..140807942 normalizes horizontal target, computes
dot/cross, and limits the turn by elapsed DWORD milliseconds. Angular speed
is clamp((1-dot)*3,.55,1.55)*4000/1e6 per millisecond; run animation4 doubles
the pre-clamp term. If within that angular limit it adopts the target.
Idle/base0/1 and restoration53/54 have a .99 dot dead zone and request native
turn animations80..83 depending on side/body. Other movement bases do not use
the idle dead zone. Original normalize, cross, float operation ordering,
sinf/cosf and elapsed time are used by the comparison oracle.

Native reader140783741 calls path installation1408001f0 only when no endpoint
exists or the new endpoint is over.001m away. It also retains the prior script
movement flag in its OR branch. These initially suspicious behaviors in our
implementation are deliberate native behaviors; neither was changed speculatively.
Bounded actual reader text is native-movement-reader-path-install-v2.txt.
REA full reader response exceeded transport budget; retained view0..65000 of
79947 characters includes the relevant assignments/branches. Remaining reader
text is not claimed as newly reviewed. Reader/install collision joining and
complex WOK projection remain the previous documented adapter boundaries.

## Implementation and validation

network_facing.js reproduces finite-vector807690. NetworkMotion stores packet
facing as a target, initializes display facing only on creation, selects current
path heading while moving, and advances displayed orientation on every frame.
The camera consults that display orientation through its existing native modes.
Canonical positions, paths, IDs, rates, action admission and requests stay
server-owned. No client-side route or arbitrary interpolation delay is added.
Native turn animation requests are retained as facingTurn presentation state;
the corresponding native turn-clip event lifecycle is not newly reconstructed
or claimed here. This section fixes rotational discontinuity, not every
possible source of perceived walking/feet/input latency.

inspect-native-network-facing.py executes complete807690 and original vector,
sqrt and SSE CRT trig. Model lookup, animation restore/request and final setter
are explicit captured boundaries; no live game process changes. 1176 cases
match JS within2e-6 on output vectors and exactly on turn requests. Oraclev1
missed the sqrt dependency, v2 executes it and passes; both retained.

36 initial focused tests and60 movement/scene/combat/camera regression tests
PASS. Existing3933 movement-distance/cursor/acceleration/correction oracle
cases still pass. New tests cover frame-driven idle turns, right-angle path
heading continuity, canonical nonmutation and repeated endpoint suppression.
Buildv1 PASS with the existing bundle-size warning.

Live vanilla-server v91 issued four movement requests in the starting room,
received four server paths, returned to native position[6,3] and idle pause1.
Zero runtime errors, movement failures or sampling failures. This exercises
typed walk requests, not physical pointer picking. v91 normally closed and
its full wire/report was then read. No original client/server restart occurred.

replay-network-facing.mjs compares the backed-up replacement implementation
against this change using the same real v91 wire delivery times at60Hz:
3860 replay frames,4 path packets, canonical objects unchanged. Old maximum
packet-time turn90deg; new maximum0deg. New maximum per-frame turn6.03898deg,
no frame turns over20deg. Old per-frame statistic alone excludes its packet
jumps and must not be described as smoother. Replay uses a flat height boundary
and is not GPU timing or a turn-animation clip validation.

v92 runs the same build with no automated movement/actions, for the user's
comparison. Its normal-close full report is not yet sealed/read. Diagnostics
and readiness are frozen separately; active stdout/stderr/control/live files
are excluded from the checkpoint. HUD section backup remains verified at
multiplayer-hud-buttons-20261018-v2.zip (14317files/363130366bytes), scope48
required present, forbidden0, duplicate0, credential candidates0.

This confirms and fixes one concrete source of jerkiness. Further perceived
straight-line stutter requires frame/path timing evidence; the original video
alone cannot prove every translation, collision or animation behavior matches.
