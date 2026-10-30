# Binary-guided streaming, full native migration, then reference wiki

Status: active; incomplete. User direction: 2026-10-25 after repeated live-world
shutdowns. This ordered goal preserves the earlier native rendering/performance
requirements and expands the eventual native migration to all JS functionality.

Latest frame-admission increment:
[NATIVE-PARTICLE-ADMISSION.md](NATIVE-PARTICLE-ADMISSION.md) maps original
animation gates, model classification and BSP emitter sphere tests. Native
conservative admission, exact original/GPU checks and default local reconnects
pass. The captured-room improvement is small (36.8 versus 38.1 ms); 60 FPS,
full effects/moving replay, unresolved faults and complete migration remain open.

1. Research the unchanged original NWN:EE binary's world join, area admission,
   resource loading/cache/priority, object streaming/construction, attachment
   behavior, frame/culling work and cleanup. Record target hash, exact functions
   and call sites, original-instruction checks and open lower boundaries.
   Implement the evidenced methodologies in native Godot, then verify stable
   server-authoritative play on owned localhost Prelude and existing captures.
2. Continue migrating every remaining JS client feature to native Godot. The
   default rendering flow must not depend on JS resource/presentation preparation,
   Three, Electron/offscreen staging, GLB scene conversion, base64 asset transfer
   or JS particle workers. Non-rendering protocol JS is transitional, not the
   final full-native runtime. Keep original asset/gameplay fidelity and allowed
   engine lighting differences.
3. After full migration, write an easy-reference Markdown wiki/index for the
   project's .md evidence and systems: implementation/test entry points, source
   and report links, verified behavior versus limitations, and investigation
   routes for the user or a fresh agent.

Acceptance still requires actual launcher audits, cold/warm load phases, moving
creatures/equipment/effects, input/UI, repeated transitions/reconnects, resource
cleanup and sustained CPU/GPU/frame measurements toward at least 60 FPS. A frozen
or incomplete scene is not acceptance; an unexplained native fault stays open.
Keep migration inventory/evidence current and make verified source backups at
substantial changes. Preserve original binaries/assets/Ghidra and user sessions.
Automated tests use owned localhost or existing captures; no new public-server
connections without explicit authorization.

Latest crash: `native-session-1792920068197` exits1 on remote creature4294965096's
missing `lhand` anchor; controlled creature is4294965453. Zero workers remain and
finish is acknowledged. This is a deliberate fatal asset-error path, not evidence
of a native access violation. Initial original comparison identifies
Gob::AttachToObject14008c540..14008c6eb: missing parent/part clears its behavior and
returns null, without changing scene. Derived Wield14099d340 ignores the returned
attachment pointer and continues its own bookkeeping/scale path. Full join and
streaming methodology research is still in progress; these are not completion.

Follow-up: [NATIVE-WORLD-MODEL-CACHE.md](NATIVE-WORLD-MODEL-CACHE.md) records the
original FindModel hit/miss and private instance-tree methods and the new bounded
native template cache shared across static-stream batches.80 original cases,
16 native cross-batch checks,147 reference GPU checks, the original captured room
and actual default local entry pass. Complete scheduling, cold/warm moving-world
transitions, effects/frame pacing and the broader ordered goal remain open.

Further progress: [NATIVE-WORLD-FRAME-ADMISSION.md](NATIVE-WORLD-FRAME-ADMISSION.md)
records complete area-receiver and bounded module/area/item views. Native world
poses for noncreatures now update on receipt/admission; moving creatures still
tick each frame. Eight authored live-world checks and actual default local
movement while streaming pass. This is not full binary dirty/culling parity or
a measured dense-world FPS gain; no new public connections were made.

Object admission follow-up:
[NATIVE-VISUAL-ADMISSION-FAILURES.md](NATIVE-VISUAL-ADMISSION-FAILURES.md) records
54 complete original placeable/door/trigger loader cases and scoped native
placeable/door failure isolation. Failed bindings stay explicit, stop identical
retry loops, recover on changed appearance, reject stale results and never count
as admitted. Required actor/table failures remain fatal. Final native/GPU and
owned localhost checks pass; full cancellation/replication policy remains open.

Repeated local traversal coverage:
The new [NATIVE-SESSION-RENDER-CACHE.md](NATIVE-SESSION-RENDER-CACHE.md) retains
bounded immutable native render resources across worlds. Actual Prelude return
visits build no additional pooled resources, private owner/eviction regressions
pass and shutdown drops cache bindings. This is an explicit Godot adaptation
of evidenced global source/private instance ownership, not exact original LRU.

Repeated local traversal coverage:
[NATIVE-WORLD-TRANSITION-CHECKS.md](NATIVE-WORLD-TRANSITION-CHECKS.md) verifies
three real server-authoritative Prelude door transitions in one native client,
complete object admission and inventory reopening, with released world owners
and no pending workers. Same-process reconnect, complete effects and controlled
dense-world/cold-warm acceptance remain open.

Retirement follow-up:
[NATIVE-WORLD-DEFERRED-RETIREMENT.md](NATIVE-WORLD-DEFERRED-RETIREMENT.md) maps
the original area teardown boundary and records the Godot-specific deferred
worker-owner adaptation. Actual blocked workers across six cycles cannot stall
new-world preparation or publish/remove new-registry IDs. Bounded overflow,
cleanup, the ordinary authoritative Prelude door transition and actual default
entry pass. This is not proof of the original async-cancel algorithm, complete
repeated transitions/reconnects, effects or dense-world performance acceptance.

Effect-owner follow-up: [NATIVE-PARTICLE-CHUNKS.md](NATIVE-PARTICLE-CHUNKS.md)
maps the original chunk lifecycle and nonempty RenderNothing model-transform
path, with110 original bounded traces and119 coupled native/GPU checks. Native
presentation services can activate it; automatic live-world asset/service
binding, nested ownership and full effects remain unfinished. Standard GPU and
actual default local entry regressions pass. No new public connections.

Source-word follow-up: [NATIVE-PARTICLE-SPAWN-WORD.md](NATIVE-PARTICLE-SPAWN-WORD.md)
fixes six actual Prelude emitters rejected for unsigned spawnType=0xFFFFFFFF.
The original dword-zero branch is preserved, with224 new unchanged-original
cases and scoped compiled/default-local regressions. This corrects a native
adapter failure; full scene physics/effects and broader acceptance remain open.

Connection lifecycle follow-up:
[NATIVE-SESSION-CONNECTION-SCOPES.md](NATIVE-SESSION-CONNECTION-SCOPES.md) adds
connection ownership to the private native bridge. Actual default-client testing
disconnects with real unfinished workers, then completes three joins in the same
Godot PID, rejects retired messages/commands in both directions and releases all
retired worlds/workers/cache bindings. Original disconnect coordinator evidence
is scoped separately. Remote handoffs, catalog-stage cancellation, full effects,
dense performance and complete migration remain open.

Automatic integration follow-up:
Native point-source effects:
[NATIVE-SCENE-POINT-WIND.md](NATIVE-SCENE-POINT-WIND.md) ports scene-owned radial
wind registration/lifetime/vector state with original observation and native/GPU
checks.472 more captured emitters simulate, exposing adapter/channel CPU cost;
full collision/ambient wind/effects and performance remain open. Preserve those
emitters while reducing overhead.

[NATIVE-PARTICLE-DISPATCH.md](NATIVE-PARTICLE-DISPATCH.md) now verifies direct
native update/movement dispatch with exact moving-frame output, lazy constant
channels, final default-client reconnects and same-build captured comparisons.
The diagnostic C++ field-copy path did not improve timing and remains opt-in.
The room still takes about36 ms/frame with incomplete effects; original emitter
eligibility and persistent typed state need investigation.60 FPS remains unmet.

Automatic integration follow-up:
[NATIVE-CHUNK-BINDING.md](NATIVE-CHUNK-BINDING.md) wires shared native chunk
preparation, private models, nested references and cancellation. Live streams
now publish directly into their final world so in-tree reparenting cannot retire
effects during adoption. Original NULL model semantics are preserved. Scoped
GPU, actual default local and captured-room checks pass; complete scene physics,
full moving replay/performance, repeated transitions and migration remain open.
