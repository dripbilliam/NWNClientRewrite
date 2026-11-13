PRIVATE CAMERA DIAGNOSTIC — root owns launch scheduling

Source-only derivative of the FINAL promoted production selection. No fixed C45,
engine or particle hash. Preparation requires the root-provided exact current main
source SHA and validates it before cloning. No existing capsule/main is edited.

Preparation (only after final normal acceptance/promotion, outside FPS windows):
  node tools/native-render-gap/original/camera-diagnostic/prepare.cjs 
    --selection=<FINAL production-selection.json> --sha256=<selection SHA>
    --main-source=<FINAL current main source SHA> --label=final-d-a

The emitted manifest/frozen source directory pins the base, one private native
session observer, driver/helper, selected native libraries and all compiler-free
source inputs. It retains actual final configuration/flags and common preference
seeds. The derivative is explicitly diagnostic-only, not a promoted production
selection. Each copied source file remains private; only large immutable JSON
evidence can be hardlinked.

Run SEQUENTIALLY, once root authorizes the graphical slot:
  node tools/native-render-gap/original/camera-diagnostic/run.cjs
    --stage=<emitted stage directory> --mode=static --run=camera-final-d-static-a
  node tools/native-render-gap/original/camera-diagnostic/run.cjs
    --stage=<same stage directory> --mode=yaw --run=camera-final-d-yaw-a

Both use the original capture/generation2/input timeline and unchanged prediction
receipts. Only after timeline delivery, object_visuals_complete, zero pending
batches and original settle do they run the SAME20s camera prewarm path followed
by5s rest. Existing native begin-performance-window acknowledgement starts a new
bounded measurement. The static role sends the same60Hz metadata/no-op yaw;
the moving role sweeps terminal yaw±20deg with5s period for20s. Both request actual
camera observations at5Hz, then restore and observe the original terminal view.

Main/RT settings, particles, FOV, pitch, distance, focus, server state, request IDs,
actor lifetime and captured authority are never rewritten. Scope/readiness or
actor motion changes reject. Actual global camera pose (not just requested yaw)
must move in yaw mode and remain stable in static mode. Counters/readback overhead
is shared. These are60Hz protocol camera commands, not physical input or a claim
that every rendered frame changes view.

Read acceptance.json for each role. Primary throughput is exact native Engine
process-frame delta / monotonic ticks between actual start/end observations;
it is NOT displayed/GPU FPS. Driver hello-origin elapsed/UTC boundaries align the
rolling Engine FPS samples with2s leading and0.5s trailing margins. Original
prediction, terminal-camera, normal positive-feature-use, clean exit and loaded
engine/particle/resource provenance gates remain mandatory. A single pair is
diagnostic and cannot establish a repeated optimization or original-client parity.

Runtime checks performed so far:
  oracles-b: real75bc headless parser/deferred/scope/lifetime/readiness/counter
  helper13checks + deterministic host static/yaw7checks, clean. No real camera
  scene/graphical run or final production-base staging has occurred yet.
  oracles-a retained: functional checks passed but missing empty global-class
  cache emitted an engine error; not accepted. b fixed only this test setup.

Standalone bounded checks, only when root releases CPU/headless slot:
  node .../source-oracle.cjs source-check-a
  node .../run-oracles.cjs --engine=<exact executable> --sha256=<SHA> --label=oracles-c

No engine compilation is needed. If final source seams or gates fail, stop and
retain failure evidence; do not weaken final normal acceptance or the quiet-camera
verifier. Original recorded-input medians remain an earlier warmup/loading phase.
