# Finer stream and transition attribution

2026-10-27. The opt-in preview/null-model fix remains in place. This change adds
timing boundaries; it does not claim a new FPS improvement or original-client
parity. No public server connection or original-binary mutation was made.

The native session now records a finite set of message-kind child timings and
counts. Unknown message names share `other`, keeping profiler cardinality bounded.
The spans measure the synchronous handler portion, not awaited continuations;
they overlap `protocol_apply` and must not be added to it.

Object-stream timings split priority sorting, request submission, template work,
door setup/private cloning, scene attachment (including ready callbacks), and
publication bookkeeping. The scheduling budgets and canonical objects remain
unchanged. Old-area hide and inherited processing disable have separate spans;
their maxima also persist in the final retirement receipt, including transitions
not retained by the rolling frame sampler. These are per-world peaks, not additive
peaks from necessarily the same frame.

## Observed evidence

`native-loading-fine-stream-spans-area4-v1`: complete frozen 630-entity area,
clean CDB/engine/lifetime gates, source unchanged, all workers joined. Sampled
phase maxima: template 10.535 ms, attachment 9.125 ms, private clone 1.596 ms,
priority 0.622 ms, requests 0.402 ms, raw-world-end 4.234 ms. They are different
frames and may include multiple units; do not add them or call each a single
model's cost. The final persisted-timing source was rerun as
`native-loading-fine-stream-final-area4-v1`: all630 complete and clean, sampled
template 12.707 ms, attachment 7.120 ms, clone 1.550 ms, priority 0.732 ms.
These are diagnostic observations, not controlled timing comparisons.

`native-loading-fine-stream-final-local-v1`: two headless authoritative Prelude
connections, all gameplay checks accepted, one stale-input probe and four stale
session messages rejected, final protocol acknowledgment and no remaining workers.
The small world's retirement reports hide 0.605 ms and processing disable
0.444 ms; no forced drain. It does not explain the earlier dense room's 35–36 ms
combined disable boundary. Current retirement/physics/publication regressions
cover the actual lifecycle and budget contracts, not merely timer values.

## Original evidence and next decision

Read-only saved `../backups/animations/rea-native-stream-new-object-v1.json`
covers NewCAurObject 0x1400931f0..0x140093847 for original NWN binary SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Its recovered calls include FindModel 0x140098cd0, LoadModel 0x1400a0130,
CreateInstanceTreeR 0x14008dab0, CreateReferenceObjects 0x14008db90 and
PartInitMaterial 0x140093850. This supports shared definitions and private
instance/reference/material state, not an assertion about unobserved native
frame timings or culling/submission batching.

Queue sorting is not the dominant measured object-owner cost. Investigate tree
entry callbacks and private scene publication before adding workers or reducing
sorting accuracy. Any static geometry batching candidate must retain original
textures, physical queries, source transforms, shadow/material distinctions,
references, emitters and independent mutable state. Animated/skinned or uncertain
models require a compatible path; do not silently freeze or omit them. Validate
source geometry and rendered output before treating reduced node/draw counts as
a successful optimization. Large outside-callback stalls remain unattributed.
