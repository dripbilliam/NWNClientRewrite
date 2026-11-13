# Performance test queue

**Partly executed; performance acceptance is unmet.** Following authorization,
30 CPU groups (244 checks), three GPU fixtures, an installed-model roundtrip
and five local scenarios (24 area visits) passed. The preview comparison
failed before entering its first area because its isolated build URL was not
trusted by IPC. The exact-document trust configuration is corrected and
tested; the native paired comparison still needs a rerun. The final normal
boot stage did not run after that failure.

See [execution and live findings](../../docs/performance.md)
for exact reports, timing caveats and subsequent focused checks. The local
queue never connects to Arelith. The user subsequently requested a separate
experimental build and manually joined Arelith; read-only live evidence is
recorded separately. Normal `dist` is unchanged. Do not run benchmarks while
the user's game is active.

The manifest includes deferred checks for newer diagnostic/launcher work.
Listing reports the current selection; execution records in each unique run
directory, rather than the manifest, establish which version actually passed.

## Running later

From the workspace root, listing the queue starts nothing:

```powershell
node .\scripts\performance-queue\run.mjs --list
```

Once the original and replacement games are closed, run a read-only preflight
or the staged queue:

```powershell
node .\scripts\performance-queue\run.mjs --preflight
node .\scripts\performance-queue\run.mjs --run --stage=all
```

For a shorter first pass, run stages separately in this order:

```powershell
node .\scripts\performance-queue\run.mjs --run --stage=unit
node .\scripts\performance-queue\run.mjs --run --stage=gpu
node .\scripts\performance-queue\run.mjs --run --stage=installed
node .\scripts\performance-queue\run.mjs --run --stage=local
node .\scripts\performance-queue\run.mjs --run --stage=compare
node .\scripts\performance-queue\run.mjs --run --stage=boot
```

`--only=id,id` narrows the selected stage. Run correctness and GPU checks
before native performance comparisons. The queue stops at the first failed
exit code, missing/unsuccessful report, skipped required CPU coverage or
source mismatch. A deadline warning waits on the existing process instead
of launching a second attempt. Ctrl+C requests a stop after that process
finishes. A hung process may need its own window closed; the queue never
blindly kills process trees.

The runner refuses to launch while `nwmain.exe`, `nwmain-windows.exe` or
`electron.exe` is present. This conservatively includes unrelated development
Electron instances. It prints only their names and PIDs. It does not close
them. A queue lock prevents overlapping queued runs; inspect its owner before
removing a stale lock after an interrupted runner.

## Coverage and interpretation

| Stage | Main checks | Evidence produced later |
| --- | --- | --- |
| CPU | Texture consumers; hidden preview hierarchy; real particle buffers/RNG; worker ordering, bounds and cancellation; source/disk cache ownership; palette isolation; shadow invalidation; picking; skin/deform exclusions | TAP output, failure logs, exit codes; skipped required coverage fails |
| GPU | Exact original/candidate color and point-shadow output; 24 live-particle/negative-scale frames; 24 ordinary/shared geometry frames per mode; 16 cold/disk-reloaded geometry frames; native mesh picking and disposal | Image hashes, shadow hashes, screenshots, ownership reports |
| Installed | Existing native model bytes through worker, memory and disk; own parsed data, geometry attributes/groups/bounds/picking | Content hashes and counts only; derived cache is private OS temp |
| Local | API resource audit, long steady baseline, resolution control, shadow control, 12-visit transition soak | Frame-gap distributions, sampled internal work, CPU profiles, loading timelines, moving actors and ownership retirement |
| Boot | Existing normal `dist`, zero joins/fetches, experimental defaults and QA hooks off | Offline production-boot report |

Local-server matrix:

| Scenario | Visits | Render buffer | Shadow setting | Steady observation per visit |
| --- | ---: | --- | ---: | ---: |
| Resource API audit | 3 | 3440 × 1369 | 1 | 8 s |
| Ultrawide baseline | 3 | 3440 × 1369 | 1 | 30 s |
| Resolution control | 3 | 1424 × 921 | 1 | 8 s |
| Shadow control | 3 | 3440 × 1369 | 3 | 8 s |
| Transition soak | 12 | 3440 × 1369 | 1 | 8 s |

Each visit asserts the **actual** scene shadow maximum and render dimensions,
a rendered controlled character, no failed models and at least ten moving
crowd actors. The final disconnect requires all area workers, preparation
owners, geometry leases, shadow instances, material edits, texture work and
program leases to retire. Actual retirement counts must match visit counts.

The injected RAF observer records each callback gap during loading and steady
phases. It reports weighted FPS, nearest-rank p95, maximum, gaps over 50 ms and
freezes over one second. Internal CPU work telemetry is published by the
existing renderer every 200 ms, so it remains sampled; it must not be presented
as per-frame internal timing. CPU profiles are also enabled. RAF gaps and CPU
profiles do not measure GPU duration or server latency. Instrumentation has
overhead and must remain identical in any future matched comparison.

The `sampledLocalTargetMet` field checks at least 120 frames, >=60 FPS,
p95 <=16.7 ms and no gap >=1 second in that local sample. A successful test
means the fixture ran correctly, even if this field is false. It does not
complete the optimization goal or establish performance in every live area.
The first loading visit also differs in render size before its initial
resize; compare like visits, not initial connection with a hot transition.

The API audit records request name/type, generation, elapsed wait, result size
and error code. It holds bounded MDL references in memory and parses them
**after disconnect**, then drops them. Resource bytes, credentials, actor
descriptions and private messages are not written into the audit. Repeated
API requests are distinct from repeated disk reads or repeated decodes; cache
hits and fallback attempts below that boundary require separate evidence.
Elapsed resource waits overlap and cannot be summed as CPU time. Audit runs
are diagnostic, not uninstrumented FPS acceptance runs.

## Candidates remain isolated

`scripts/performance-candidates/model-texture-usage.mjs` audits the current
replacement builder's texture consumers. It retains all visible material
slots and dormant emitters, preserves resref spaces, and falls back to the
full catalogue on unknown data or a catalogue/consumer mismatch. It does not
change `materialNames`, PLT override precedence or production loading. Binary
secondary texture layers are described as unconsumed by the current builder;
this is not a claim that native NWN ignores them.

The preview fixtures extract the actual production `buildObject`, `buildMesh`
and preview functions without importing/booting `src/main.js`. They compare
`previews:true` with `previews:false` while the editor preview checkbox is off.
Real native particle presentation is retained in both modes. The source-viewer
checkbox, animated atlas and preview visibility have a separate correctness
case. No network factory has been changed to opt out yet.

The normal texture selection, gameplay-preview opt-out and disk model cache
stay off. The isolated live build deliberately enables ten experimental
candidates, with a Baseline switch; this is diagnostic authorization, not
evidence for enabling normal defaults. The newer volatile-shadow input-scan
candidate is also off by default and has not been deployed or benchmarked.

## Ownership, reproducibility and next comparisons

`source-contract.json` pins source, test harness, manifest, current bundle and
installed binary identities. Source drift stops the run. After intentionally
changing production code, review the extraction/consumer assumptions and
refresh the contract hashes explicitly before using these results. Do not
silently bypass a mismatch or reuse an old build for a new source claim.

The local stage starts only the existing authored `DensePerf` fixture on
127.0.0.1:5123, with public listing and NAT punching disabled. It requires the
already-created fixture module, installed original assets and saved protected
local CD key. Other local servers on 5121/5124 are preserved. If 5123 is
occupied, startup fails. Cleanup verifies the exact leased server PID,
creation time, executable and private profile before stopping it. Temporary
model caches use unique OS directories with checked cleanup paths.

Each execution writes a unique directory under
`runtime-logs/performance-queue/queue-.../`, with `summary.json`, stdout/stderr,
native scene reports, RAF observations, profiles and screenshots. The reused
GPU/native/boot probes also write uniquely versioned reports under
`backups/animations`; their exact paths are in the summary. Old evidence is
not overwritten. The comparison stage builds only into an owned isolated QA
directory; it does not overwrite normal `dist` or persist menu preferences.

After this queue is validated, use its audit to choose the next implementation
experiment. For preview removal, texture pruning, palette/source reuse or a
whole-object preparation pipeline, change one variable at a time, preserve a
normal baseline, and run at least four alternating matched pairs. Measure
cold activation separately from hot reuse. Record actual object/light/draw
counts and camera motion; moving native NPCs make cross-process FPS comparisons
noisy. Texture pruning and whole-object pipeline integration are not implemented
or automatically toggled by these prepared tests. Keep candidate features off
until correctness, GPU output, ownership and whole-client comparisons support
enabling them.
# Offline captured-room replay

The decoded recorder and replay path are documented in
[`offline-scene-replay.md`](../../docs/research.md). Native
payloads remain in private AppData; do not copy them into this workspace.
The supplemented heavy-room replay now imports the complete canonical object
inventory without resource gaps. Its original final-frame parity gate still
fails because the recorded final frame was partially loaded. Current FPS is
exploratory, not an accepted optimization result.

With games closed, build an isolated replay diagnostic bundle using a **new**
output/report path (the builder refuses overwrite):

```powershell
node .\scripts\performance-queue\prepare-preview-build.mjs --run --diagnostic --replay --out=backups/animations/performance-queue/scene-replay-next/diagnostic-build --report=runtime-logs/performance-queue/scene-replay-next-build.json
```

Run `scripts/performance-queue/replay-scene.cjs` using Electron with `--run`,
`--capture=<private capture directory>`, `--build=<that diagnostic-build>` and
`--output=<new report under runtime-logs/performance-queue>`. As with other
Electron launchers, remove `ELECTRON_RUN_AS_NODE` from the child's environment.
It blocks external requests and never connects to a game server. Optional
`--allow-text-gaps` enables labelled UI placeholders while keeping the parity
gate failed. `--profile=capture` (default), `baseline` or `candidates` select
the isolated graphics settings. These settings never persist to the user's
profile or normal build.

`inspect-scene-capture.mjs --capture=<private directory>` verifies the event
timeline without starting a renderer; asset bytes are verified on actual reads.

`freeze-scene-supplement.mjs` is a separate offline discovery/export step for
uncaptured requests. It requires explicit capture/report, cached manifest,
installation and profile paths, matches common resource hashes, and freezes
only requested local bytes into a private sibling directory. Replay accepts
one or more `--supplement=<private directory>` options; it verifies the parent
checksum and always prefers original captured successes and expected misses.
`--cpu-profile` profiles only the owned offline renderer after its scene queue,
graphics barrier and source-prefetch queue drain. Measurement endpoints are
read before Profiler.stop. A captured final view can still be partially loaded;
extra models in a complete import do not justify claiming exact-view parity.

Before substantial changes, run `scripts/checkpoint-performance.ps1 -Name
<readable-new-name>` in PowerShell 7. It creates a source-only ZIP and reopens
every entry to verify its hash. Private game resources and native binaries are
excluded. The initial checkpoint is `captured-room-baseline-20261022.zip`.

The latest private renderer experiments and deferred clean measurements are
recorded in [`captured-room-renderer-experiments.md`](../../docs/rendering.md).
`replay-scene.cjs --compare=baseline,flat-scene,broad-main,broad-flat,broad-flat,broad-main,flat-scene,baseline`
uses one isolated replay instance, warms each mode for 16 seconds and then
observes it for 20 seconds (the final 15-second telemetry window is reported).
It requires a matching new replay build containing those private hooks. It
never changes normal client settings. Close other games before benchmarking;
the latest run is confounded by concurrent user game activity.

The zero-contribution point-light GPU check is prepared but unexecuted. Once
other games are closed, `--run --stage=gpu --only=zero-light-work-gpu-parity`
on the queue runner includes its required CPU regression group first. The
fixture compares unmodified Three programs with the experimental guard,
including context replacement and post-disposal ordinary shader behavior.
Do not treat preparation, syntax checks or a future GPU parity pass as FPS
acceptance. The candidate is not imported by the normal application.

New replay comparisons also record full phase/loading RAF observations,
completed render counts and exact start/end content identities. Rebuild the
private replay bundle before using these hooks. `--uncontended` records the
operator's confirmation that other games are finished; omit it while that is
unknown. It is required by the prepared timing summary and does not bypass any
process guard. Profiling runs remain diagnostic. The original recorded-frame
parity gate is unchanged, and a clean steady-state comparison alone cannot
complete the broader loading, fidelity and multi-scene performance goal.

