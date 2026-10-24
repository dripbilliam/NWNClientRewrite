# Ready collision work in the input frame

Read-only original target: NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`.

The prior frame-order repair sampled input before movement, but prediction
still awaited Promises even when all collision data were cached. The new
isolated oracle composes original held tick6f1e40, preview6ea9e0, path search
7fdeb0, installation80b0d0, movement8114d0/811fc0/804bf0, correction804840
and facing807690. Synthetic plane answers, clock, outgoing messages,
object/model lookup, rules/scale, height and animation notifications are
explicit lower boundaries. This is not execution of the complete app/network
loop or original world collision. No live original process is modified.

Four initial 90-frame cases show the previous ready-resource adapter one frame
late: maximum position difference0.0256004m, initial idle absent natively,
and a native collision completion at240ms delayed to256ms. The negative
capture remains preserved. A resourceFlow iterator now runs the same algorithm
immediately through ready providers, yielding only for actual pending IO.
Client line/edge tests and preview search retain a single implementation and
their native float arithmetic. Ready tile references remain area/resolver-owned;
obstacle signatures still invalidate on physical changes; each query retains
its private creature positions/membership. Cold IO keeps existing generation,
control, owner and fresh-pose checks and bounded retries. No whole-frame
atomicity with received packets is claimed.

The expanded 28-case comparison initially failed combined steering against
a plane by0.000637m. We retained that rejected trace rather than relaxing
tolerance. Original6f1e40 quantizes its heading for the wire, rebuilds a float
direction using a double radian constant, and calls virtual120 before
preview6ea9e0. Static evidence is the existing keyboard-drive-ui pseudocode's
LAB_1406f262f branch; the composed original execution exercises its setter.
The replacement previously quantized only the packet. Its new onDriveHeading
hook updates the matching presentation lifetime before preview, without
changing authoritative object data. Original double trig is executed in the
oracle; replacement Math.cos/sin cast/normalize outputs are validated by the
composed finite fixture, not asserted universally bit-exact CRT equivalents.

The final28 scenarios cover forward, both strafes and combined steering,
with/without synthetic key repeats and a collision plane:2520 frames. Maximum
position delta is9.54e-7m; facing is within the unchanged2e-5 bound; native
idle and stationary frames agree exactly. Some original collision paths do
produce idle/stops, including three stopped frames in a combined case; these
are retained, not hidden with perpetual movement animation. Missing fixture
CRT ranges and a missing fixture WALKDIST/RUNDIST table caused early setup
failures, corrected without modifying native instructions or acceptance.

61 focused tests pass: ready/cold resource flow, cancellation/rejection,
installed WOK/PWK/DWK synchronous reuse, server/scene isolation, actual native
collision/search/motion vectors, heading lifetime and frame packet sampling.
The first sandbox run failed only an installed-resource scandir; scoped
read-only execution passes. Build index-DflDpZU-.js and packaged main-v17
startup/resource IPC pass without a game join or external fetch.

Only127.0.0.1:5121 was used live; owned server configurations are unchanged.
The calibrated six-input/contact run finishes normally, then sampling stops.
W/S/E have zero stationary steps; combinedA/D have5/3, Q1; deliberate Q/E
contact1/0. Actual active-path idle frames remain zero.210 accepted predictions
and1914 exact recorded collision queries match original preview/search with
maximum query9.54e-7 and endpoint4.77e-7; two active-correction inputs are now
covered. This is not a causal ratio against differently timed prior sessions.
The user reports physical movement is smoother with no obvious stop/start
jitter. Full native app/inbound ownership and broader local density remain
outside the proof. `verify-ready-drive.mjs` preserves these scopes.
