# Current-build local movement validation, 2026-10-20

The previous goal turn repaired obstacle cache invalidation and per-query
creature membership. This turn reconnects only the replacement client to the
owned unchanged Prelude server at127.0.0.1:5121, PID20964, and executes the
actual production build index-CcEowr6S.js. No Arelith or other remote-server
connection is made. The prior client48208 closes through its graceful control;
its server log records leaving with zero players before the new join. No
server restart, original-client change or original asset copy is performed.

First DOM-event trial: controlled presentation takes4240ms from connection.
Free movement passes387 translation frames without stationary steps. The
contact checker fails its unchanged >1m displacement sanity assertion:
Q travels0.822m, with eight null preview paths. This trial remains rejected;
it has no collision snapshots, so the cause is unproven. The later pass does
not erase it or establish a controlled speedup ratio.

Second trial uses Electron sendInputEvent, routed through Chromium, with
modeled repeated-key modifiers. The installed Electron declarations specify
KeyboardInputEvent and isAutoRepeat. before-input-event observes100 free-test
events, including82 repeats, and66 contact events. This is stronger than
constructing DOM KeyboardEvents; it is still not physical OS input or an
original native client comparison. Collision metadata capture is opt-in and
contains poses, numeric selectors and area tile metadata, not asset buffers.

The current build reaches controlled presentation in3548ms. All six free
sections pass, with381 translation frames and zero stationary translation
steps; A/D turn in place. Contact Q/E passes the existing displacement,
facing, active-path animation and final server-position checks, with10 partial
refreshes and25 slide paths. Q still has three held idle frames and a17.9ms
pause; E has none. continuousHeldAnimation remains false. No zero-hitch or
complete collision/ghost/bump claim is made.

The bounded passive window has236 samples across approximately two minutes:
97.3–128.5FPS, p95 frame intervals8.7–17.7ms, zero failed objects and renderer
errors. Sampling then stops. The replacement remains open as PID42536 on the
local server, with close control current-drive-control-v2 and live tool
handle47822. Automated key sequences have finished; no background movement or
unbounded full-trace rewriting remains. Unknown native message18/20 is still
diagnosed and is not hidden as a successful implementation.

Finite frozen snapshots current-drive-rejected-dom-v1 and
current-drive-chromium-v1 retain both trials. A36-frame/11-preview/four-server-
snapshot excerpt preserves the residual contact interval. Approximate installed
geometry replay reproduces shortened terrain paths with endpoints within
roughly0.006m, even without dynamic objects, but nearby published poses are not
the exact predicted input state. It is diagnostic evidence, not native
instruction/tick-order acceptance. Terrain-only replay of the eight earlier
null paths reproduces only one; every sampled frame has an active position
correction. The rejected first case therefore remains unexplained. The next
useful capture needs predicted path-position+0x2c0 at preview entry, alongside
displayed/rendered position, rather than inferring it from a nearby frame.

Read-only original review: pinned NWN:EE89.8193.37-17 x64 SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
FUN14080b0d0 copies/allocates path nodes, sets count+0x2d0 and resets cursor
pointer+0x2a0. Its decompiled body does not add a predicted-position reset;
there is no basis for inventing one to cure the rejected trial. This is
containing-function inspection, not a newly executed allocation/copy oracle
or resolved individual call-site map. The successful REA report is retained.

Assertion-checked current-drive-proof-v2 preserves the pass, rejection and
limits. Goal remains active: unexplained rejected contact, physical-key
feedback,27 additional portrait sources and broader animated/replicated/
transition/fullscreen acceptance remain open. Live tests remain local-only.

Verified checkpointv27:1418files/61082265bytes,SHA256afe4c60f928b8849c8d345f2afcca4eb702f3e326b9b3be10916440bb3fcca31. Independent audit55parents/227required entries, zero missing/newcredential candidates. Post-seal verification only.
