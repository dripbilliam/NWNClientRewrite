# Shared animation lookup during native loading

2026-10-27. Current source uses immutable worker-prepared clip indices and
controller definitions. Main-thread private AnimationPlayer resources, events,
libraries, names, clocks and transitions are created for requested clips only.
`--clip-preparation=main` retains the pre-change installation path;
`--clip-preparation=worker` selects the new path explicitly. Live diagnostics
report the actual policy and indexed model/metadata counts. Old assets without
an index use the previous route.

## Original method and deliberate adaptation

Read-only NWN:EE89.8193.37-17 x64 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Complete projected dossiers for `FindAnimation` 0x140050f80 and
`Gob::GetAnimation` 0x1400510b0 are retained in
`../backups/animations/rea-loading-animation-demand-v1.json`.
They search resident model animation definitions and recurse into supermodels;
GetAnimation also inspects current instance runs. Neither recovered function
builds a fresh full event/name/transition map merely to inspect one clip.
These complete bodies do not establish the entire original animation scheduler.

The port already shares decoded sources, but `_model` rebuilt per-instance
maps for every clip and copied every event list before initial playback.
`ActorModel.rig_asset` now adds a name-to-integer-index map during its existing
worker clip pass. No second aliased clip graph is embedded in the derivative
serialization. The derived-cache namespace changes from
`actor-rig-emitter-v9-deferred-axis` to `actor-rig-emitter-v10-clip-index`.
Immutable controller definitions are borrowed; the track builder only reads them.
Node bindings, GPU/scene publication and actual playback remain private/main.
The existing actor retirement payload already retains asset_source, which is the
same immutable graph; no live AnimationPlayer or resource is sent to a worker.

The original lookup is case-insensitive and first-match with a default fallback.
This optimization deliberately retains the port's existing exact-case/last-name
rules. Native duplicate/case/default-fallback parity is a separate open gap;
do not cite this phase as resolving all native animation selection semantics.

## Exactness and regression receipts

`tests/native_clip_index_test.gd` runs81 assertions against the unchanged authored
runtime extracted from `backups/native-loading-control-identity-v1.zip`, archive
SHA256 `ddbc1dad4b6615d72f869a4fab114fdd19a018845ebc510c606069b405ffa12a`,
runtime SHA256 `4cb7cf9ea3322ea4593d1fc8a22410437aa94ddbb671370d9b68c8b57e6a6318`.
Actual data workers and real AnimationPlayer tracks/paths/times/values, sought
poses, private event copies, clocks, repeats, missing names, duplicate/case rules,
invalid-duration omission and old/new verified derived-cache identities execute.
The602-clip authored case and original sealed a_ba/c_goblina sources are covered.
No proprietary asset copies are added to source.

Fixturev1 passed81 assertions but its complete engine log failed because sandbox
startup could not read the Windows certificate store. Read-authorizedv2/v3 pass
without filtering any engine errors. Current default full suite:
`reports/native-loading-clips-suite.suite.json`,6204 checks/41 cases, all pass
under CDB normal heap with four exception traps and unchanged source hashes.
Earlier6,123-check skin suite remains historical.

## Same-source isolated observations

Every following pair uses the same sealed original inputs and source hashes within
that pair, a fresh prepared cache, native rendering, no preview and no game network
connection. Both areas fully load441/630 expected entities with clean engine logs,
drained workers and finish acknowledgments. Order reverses across areas andv2.
v2 additionally borrows immutable controller definitions.

| Area/version | Main/worker player ready ms | Main/worker animation install peak ms | Main/worker sampled wall peak ms |
| --- | --- | --- | --- |
| 3/v1 | 3072.042 /3212.800 | 5.240 /3.458 | 54.597 /54.591 |
| 4/v1 | 3028.140 /3122.930 | 5.697 /3.489 | 54.040 /54.237 |
| 3/v2 | 3253.055 /3031.000 | 5.410 /3.611 | 55.084 /54.536 |
| 4/v2 | 3058.472 /2978.634 | 5.717 /3.399 | 53.968 /54.592 |

Runs: `native-loading-clip-area{3,4}-{main,worker}-v{1,2}`.
Main-thread child installation work is lower in each observation; readiness
benefit is not consistent across versions and the maximum wall hitch remains.
These are sampled, overlapping phase peaks and single observations, not summed
CPU totals or statistical FPS/original-client timing acceptance.

Current-source/default isolated runs
`native-loading-clips-default-area{3,4}-v1` pass441/630 entities, player readiness
3072.105/2966.822 ms, terrain1422.596/1050.527 ms, entry camera23.005/27.493 ms.
Full original-paced route pair `native-loading-clips-route-main-v1` and
`native-loading-clips-default-five-area-v1` deliver the same complete timeline,
end with922 entities and the same missing dwc_gate_02, and drain workers/cache/
retirement with clean full engine logs. Final indexed model counts0/20 prove
the actual runtime branches. Animation installation peaks10.618/6.361 ms, but
maximum sampled wall frames58.545/115.046 ms do not improve. The115 ms candidate
frame is around84 s/generation2, with108.686 ms outside instrumented callbacks,
only6.360 ms callback envelope and asynchronous render CPU/GPU1.216/1.591 ms.
Its cause is unproven; do not filter it out or attribute it solely to OS/GPU.

`native-loading-clips-default-local-v1` passes the owned authoritative Prelude
load with19 entities, no public connections, source unchanged and native exit0.
This is not a new door/combat/possession proof. Current source/receipt audit
`reports/native-loading-clips-audit-v1.json` passes with2840 focused loading
checks plus3364 native ABI checks,6204 total. Audit tool default is now clips.
The first audit invocation lacked the new6204/41 manifest expectation and failed
before writing a receipt; explicit new expectations were added without weakening
any prior phase assertion. The successful rerun validates all final receipts.
The five-area capture remains explicitly incomplete for missing source bytes.

## Remaining measured work

The approximately54 ms overall isolated peak occurs early, around700 ms, before
the player is ready. Its callback time is mostly unattributed, not the animation
installation phase. Do not label it a sustained renderer or GPU cost.
Looking after player readiness plus1.5 s, the v2 area3 pair still samples
25.3/30.8 ms frames; area4 samples26.4/23.4 ms. Area4 frames include16.5–17.4 ms
for one template publication. A3 ms frame budget cannot preempt one such indivisible
operation. Split template construction/publication needs separate investigation.
Detailed profiling itself adds occasional several-ms summaries.

Source preparation still matters: appearance2DA parsing/coalesced waits can occupy
roughly600 ms of worker time in these cold captures. Table default/physical-cell/
row-label/duplicate-column semantics are already regression-covered. A future
compiled token/row parser should compare every original field and keep independent
server data contexts, rather than hard-code an Arelith table or bypass authority.

This phase reduces one repeated installation cost. It does not remove all visible
pop-in, the terrain-to-player preparation gap, or prove full native gameplay parity.
