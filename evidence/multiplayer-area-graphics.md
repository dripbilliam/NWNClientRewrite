# Local area graphics preparation, 2026-10-20

Target: unchanged NWN:EE89.8193.37-17 x64, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
All live tests in this section use the owned127.0.0.1:5121 Prelude server.
No Arelith connection was made. Original game assets remain in the installation.

Native server area handler1404435a0 accepts client4/3, advances load state1→2,
and calls MovePlayerToArea140568520. See multiplayer-game-session.md,
multiplayer-object-replication.md and player-area-restoration.md for the existing
handler/caller evidence. Therefore the final client keeps its area-ready
acknowledgement behind successful graphics completion. Early-ack experimental
graphics-local-v1/v2 are not final protocol acceptance.

NetworkFrontend still awaits static area resources before importing subsequent
messages, but receives a separate graphics promise instead of awaiting GPU
polling inside the ordered import queue. Object state can import while shaders
prepare. A successful current session/area generation sends4/3 afterwards.
Failed, cancelled and superseded jobs cannot acknowledge. This is a client
presentation change; canonical replicated state and server simulation are
unchanged. The binary observation does not establish its complete client-side
loading algorithm.

RendererModelPreparation now prepares area color, opacity/fade and depth/distance
shadow variants together. It compiles the scene as the color source once;
passing an already-attached child plus the scene as target would double-count
lights in Three's compile path. Fade/shadow clones retain linked programs until
their area retires. Supersession releases the drawing gate immediately while
retaining polled GPU resources until every compiler job settles. Keyboard,
quickbar, picking and right-click actions wait for current graphics readiness.

No light limit, shadow quality or shader arithmetic was lowered. Native
AurSetMaxLights14007dce0 uses configurable14128e588 (initial DWORD32), but the
native per-object radius/type path is distinct from our global128-light
renderer capacity. That evidence does not justify replacing the latter with32.
See renderer-frame-scheduling.md and renderer-native-performance.md. The prior
compact-light-loop experiment remains disconnected after its measured regression.

Validation:

- 75 focused lifecycle, delivery, GPU-resource-retention, session and IPC tests
pass; production buildgraphics-v4 passes. Failure/stale-generation cases assert
that no area acknowledgement is sent.
- Actual WebGL fixture renderer-model-preparation-gpu-v4 preserves exact pixel
bytes before/after area preparation. A later static fade creates no shader
program. No shader/GL errors, source-material/geometry ownership retained.
- Local runsgraphics-local-v3/v5 complete normal Pavel/Bim dialogue, explicit
tutorial skip, door opening and transition to100-tile m0q1b. Both finish with92
objects, controlled character rendered, no failed objects/renderer errors or
pending assets/shaders. Area acknowledgement takes6015/1556ms; all92 prepared
at11894/6306ms after transition loading starts. These are separate current-build
runs with uncontrolled driver cache, not a causal before/after speed ratio.
- Runv5 then captures38 exact3100×1121 drawing-buffer samples. FPS range56.4–88.8,
sampled p95 frame range13.1–28.6ms. Ten camera-orbit samples span over300degrees;
FPS56.4–85.4. Cached programs remain22 across resize/orbit, zero new programs,
pending work or failed model preparations. This is one local academy view/orbit,
not acceptance of the earlier dense modded-server/fullscreen problem.
- Runv4 correctly failed its requested-size assertion: client dimensions were
3100×1121 but the drawing buffer included two border pixels. QA now derives the
window adjustment from actual buffer pixels; v5 verifies3100×1121 exactly.

Derived assertions: scripts/verify-local-graphics-performance.mjs and
creation-performance-graphics-proof-v1.json. Full run reports retain failed QA
attempts as well as successful ones; no authentication bodies/assets are saved.

The latest local keyboard run does NOT pass strict free-motion acceptance.
W/S/E have continuous translation and A/D turn in place, but Q records12
stationary steps at about10.07/5.69 while held. Later canonical server samples
agree with that endpoint and animation0. This is compatible with obstacle
contact, but native blocked-animation/slide/bump behavior remains unresolved.
The verifier was not weakened to turn this into a pass. Bounded failed-run
evidence is creation-performance-graphics-keyboard-review-v1.json; the prior
free-motion proof remains historical. The overall goal remains active.
