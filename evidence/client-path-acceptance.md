# Received-path connectivity and movement corrections

2026-10-20, original NWN:EE89.8193.37-17 x64,
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary and Ghidra input remain read-only. All live tests used the
unchanged owned Prelude server at127.0.0.1:5121; no remote server joins.

## Original policy and production change

Reader781e80 calls8001f0 at783773. The complete8001f0 body checks a received
path's connectivity from the displayed position before installing it. Its
line calls are8002ba,800324,80041c and8005b5; installation is8004c6 and the
disconnected-path projection call is8006e2. Calls pass radius1/64, height1/64,
and creature-check0. These settings differ from held-key preview clearance.

The repair order is: use the received path when its first point is reachable;
otherwise prepend the received server position if reachable; otherwise skip
to the first reachable later waypoint; otherwise connect the remaining old
path to the new endpoint; otherwise reset displayed/predicted position to
the received server position and install the received path. Stale nonzero
action sequences, missing areas and empty paths are rejected. The virtual+230
entry in CNWCCreature vtable140e474e8 is140800da0: its actual instructions
return the final old waypoint, or null for an empty old path.

`inspect-native-path-acceptance.py` executes original8001f0 and800da0 with
explicit synthetic line answers and captured installation, allocation,
projection and notification boundaries.73 cases/238 queries cover all repair
branches, three old cursors, displayed corrections, old/empty paths, sequence
acceptance, missing areas and empty new paths;16 cases take the reset branch.
This is policy evidence, not execution of the complete original collision world.

Previously `NetworkMotion.observe` directly installed received paths without
this admission. `acceptClientPath` now applies the verified order through a
scene-owned asynchronous adapter. Rate/orientation/animation imports remain
immediate; geometry work does not hold canonical packet import. It keeps the
latest path, captures the server position before IO, rejects replacement actors,
area changes and interruptions, and retries a changed displayed pose. At most
three attempts run per invocation; the next frame retries unfinished work.
Geometry readiness gates initial requests. Disposal cancels requests and waits
for in-flight reads before releasing resources. A stale idle/path reply can
still update rates but cannot cancel a matching newer pending path.

The acknowledgement query bypasses creature membership and appearance reads,
using the original tiny clearance. Local drive queries retain their existing
appearance dimensions and private creature iterator. Canonical server proxies
and packet encoding remain unchanged. Fallback height uses the existing local
walkmesh adapter; original model notification side effects are not independently
validated by this work.50 focused checks cover the policy, ownership and error
races, initial loading, clearance,3933 earlier native movement frames, actual
local wire replay, keyboard timing and door transitions. Production build and
installed menu/resource IPC smoke also pass.

## Live checks and remaining pauses

First built run `index-Dw3DwJ6Q.js` loaded in4114ms and had no stationary free
translation steps. Its contact run retained four stationary Q steps. That run
preceded the server-position snapshot and stale-reply race fixes and is retained
as `creation-performance-path-acceptance-capture-v1.json`.

Final build `index-CB1fznlH.js` loaded in3442ms. Free W/S/Q/E sections had no
stationary steps; A/D turned in place. Combined W+A and W+D moved and turned,
with one and two stationary steps respectively. The repeated key stream was
modeled and routed through Chromium, not a physical OS keyboard trace.

The later contact setup used ordinary server walk/turn requests after the
combined sections. Q had71 stationary steps and three held idle frames; E had
two stationary steps and three held idle frames. The largest Q stop was575.2ms,
E15.8ms. These numbers are retained, not declared flawless or compared as a
controlled speedup against earlier scenarios.22 shortened-path refreshes and31
slides executed.59 finite passive samples retained the rendered controlled
actor, no failed objects and no renderer errors. Scripted input and recording
finished; the replacement remains open locally.

Exact original6ea9e0+7fdeb0 replay of the final free/combined/contact capture
checks286 accepted prediction calls/2451 ordered queries, including25 null
paths and nine active-correction inputs. Maximum query/endpoint difference is
4.768e-7 units. Collision answers remain explicit captured boundaries; this
is not full native-world acceptance. During the575ms stop,13 captured predictions
had all38 collision queries rejected and the original installer also admitted
no path. The predictor continued executing, so the record does not show an
IPC wait causing that stop. The correctness of the rejecting collision-world
answers is still a useful next investigation.

The final capture and proofs are `creation-performance-path-acceptance-capture-v2.json`,
`native-path-acceptance-v1.json`, `native-exact-drive-preview-v5.json`, and
`creation-performance-path-acceptance-proof-v1.json`. `verify-path-acceptance.mjs`
checks scopes, current bundle, source/artifact hashes and retained pauses.
The separate contact-only exact replay v4 is a subset of v5; their counts must
not be added. The native reader's larger analysis exceeded the MCP response
budget; its completed retained evidence is ev_aa650eff591182d5e4020bda20ebf454f526ad96fdb07999237b9167dcc85ee1,
with pseudocode coverage79947 units and next offset64 after the first page.
That transport limit does not invalidate the independently complete8001f0 body.

Remaining work includes collision rejection at the recorded blocked corner,
bounded local message-delay testing, physical-key feedback, actual dense-world
loading/transitions/fullscreen, and the previously recorded resource gaps.
