# Current-build local update-delay check

2026-10-20. Only the owned unchanged Prelude server127.0.0.1:5121 was used.
The prior replacement was gracefully disconnected through its existing control
file. Two runs use current build `index-DZu8rJBr.js`, the same existing wizard
BIC, eight free/combined input sections, ordinary walk/turn contact setup, two
four-second strafe sections and a finite ten-second passive window. Input was
routed through Chromium with modeled repeats; this is not physical-key/native
client acceptance. The server and other clients were not restarted.

The second run queues complete decoded inbound application messages for180ms
over30seconds. Reliable transport acknowledgement/decompression, initial
admission and outgoing keyboard requests are unchanged. Message bytes are
detached at admission to the QA queue, kept in order across its end boundary,
and transferred unchanged to the asynchronous session importer. The harness
restores the original emitter automatically after draining. It saves timing,
length and hash metadata, never raw queued payloads or login credentials.
Four focused harness tests cover detachment, FIFO/end-boundary restoration,
discard cleanup, and asynchronous byte ownership. An initial helper test caught
clearing delivered bytes too early; that was fixed before either live run.

| Observation | Baseline |180ms application delay |
|---|---|---|
| Connect to controlled presentation |3549ms |3752ms |
| Free W/S/Q/E stationary steps |0 |0 |
| Combined W+A / W+D stationary steps |3 /1 |3 /5 |
| Contact Q / E largest pause |322.4 /17.7ms |24.1 /23.8ms |
| Captured correction frames |319 |0 |
| Captured stale nonzero action replies |3 |47 |
| Passive FPS range |128.8–137.6 |125.5–137.9 |
| Passive frame p95 range |8.0–8.8ms |8.1–11.5ms |

These are separate observations, not a causal speedup comparison. NPC state,
timing and contact paths differ, and pauses remain. Both runs retain three or
more combined-input stationary steps and held idle frames on contact. Neither
is declared flawless.19 finite samples per run retain the controlled actor,
zero failed objects and zero renderer errors. The known unsupported game-message
diagnostic remains recorded; no new movement/admission/session failure occurs.

The delayed run delivers89 queued messages in order, with zero discards and
maximum queue depth2. Observed delays are180.112–192.385ms. The harness has
finished, restored normal delivery and has no queued messages. It exercises
stale replies; it does not happen to produce active correction. The separate
baseline supplies correction evidence rather than hiding this distinction.

Original6ea9e0+7fdeb0 exact prediction replay checks288 calls/2245 queries from
the delayed recording and295 calls/2611 queries from baseline. Baseline has31
corrected inputs and31 null paths; delayed has neither. Across583 calls and4856
queries, maximum query/endpoint coordinate difference is9.537e-7 units. Collision
answers, controlled-object lookup, animation query, allocation, path installation
and refresh notifications remain captured boundaries. No new native whole-world,
frame-scheduler, transport or GPU acceptance is implied.

Production code did not change this turn. The91 focused production checks from
the prior checkpoint still match current source hashes, and four new QA helper
checks pass. Current ownership fixes have now run in normal live movement, but
no live same-ID recreation was forced. The second replacement remains open
locally after scripted input, finite capture and the delay have all finished.
No credentials were written to reports, argv or files.

Frozen captures: `creation-performance-local-delay-capture-v1/v2.json`.
Native reports: `native-exact-drive-preview-v7.json` (baseline), v6 (delayed).
`verify-local-delay.mjs` checks delivery bookkeeping, current hashes/bundle,
free movement, retained contact pauses, correction distinctions and replay.
Its proof is `creation-performance-local-delay-proof-v1.json` and explicitly
keeps the overall goal incomplete. Actual dense animated/replicated areas,
transitions/fullscreen, physical feedback and resource gaps remain separate.
