# Native resource loading and caching parity

Unfinished prior goal, started 2026-10-30. The user has now prioritized
[nested radial parity, then particle performance](NATIVE-RADIAL-PARTICLE-GOAL.md).
The all-resource requirements below remain outstanding, not completed or waived.
Target resource and world-loading performance
at least as fast as the original NWN executable. This covers all resources,
including models, textures/palettes/materials, animation/supermodels,
tiles/walkmeshes, audio/music, rules/2DA/TLK, GUI/fonts/icons, archives,
Workshop, NWSync and server overlays. It is not a menu-only optimization.

## User authorization

The user explicitly permits major foundational changes, provided backups are
made. Previous user-imposed experimental overrides or safeguards do not constrain
this investigation or testing. Keep a verified rollback checkpoint before each
significant architectural change; identify experimental failures separately from
accepted improvements. Use the original binary's methods as the primary reference.
These permissions do not make an unmeasured change a performance success.

## Work and acceptance

Compare native resource lookup, residency, request coalescing, source reads,
decompression, decoding, model dependencies, publication and release. Retain
unchanged data across catalogs without sharing server-specific resref bindings
or mutable live objects. Preserve server/mod precedence and content invalidation.

Measure comparable cold/warm startup, reconnect, area transition and first-use
streaming, including worst frame stalls. A passing functional fixture or a
faster warm catalog is not original-client loading or FPS parity. The goal stays
active until measured scope and remaining gaps are explicit.

## Implemented resource-manager work

Process residency now retains content-validated immutable archive/directory
indexes, ordered binding maps, decoded source data and verified NWSync bytes.
Bindings still belong to the selected catalog; live instances and their mutable
state remain private. Loose-directory enumeration no longer stats every file.
Actual demands validate/read current payloads. Same-size table changes, changed
payloads, layer order, deletion, errors and concurrent demands have fixtures.

Optional NWSync raw-cache saves now use the bounded prepared-write service;
directory pruning runs at writer idle and yields to new writes or shutdown.
Resources remain available if this writer is busy, absent or full. Queue buffer
ownership and last-owner/new-owner handoff are covered. Existing calculated-model
prework remains valid across these IO-only changes while dependency validation
and calculation schemas are retained.

Ghidra evidence: `reports/native-resource-residency-ghidra-v1.json` and `v2.json`.
The native Demand fast path returns resident bytes, Release can retain reusable
data, and directory indexing uses enumeration attributes instead of per-file
metadata calls. Native manifest service has no full raw-cache directory sweep.

## Measurements and remaining work

Full installed/Workshop/profile catalogs (19 mods, 66 HAKs), three fresh catalogs
in one process with exact resource identities across nine types:

| Source | First mount | Second | Third |
| --- | ---: | ---: | ---: |
| Previous Godot checkpoint, workshop-prior-v1 | 8403 ms | 8767 ms | 9285 ms |
| Current residency work, workshop-v4 | 2622 ms | 76 ms | 80 ms |

These compare Godot builds, **not the native NWN executable**. Timing varies with
OS cache state. Reports have prefix `reports/native-resource-residency-`.
Previously downloaded Arelith content is tested offline: `downloaded-private-v1`
used an initially empty raw cache, checked cleanup, and measured source reads at
113 / 29 / 26 ms. Cold catalog setup still took 6290 ms, then 353 / 349 ms. No
public connection was made. Cold per-entry KEY/HAK/manifest parsing is the next
target; broader direct consumers, audio/TLK and original-client timing comparison
remain to be audited. The goal remains active; native loading/FPS parity is unproven.

The subsequent compiled resource-index implementation and archived recording
benchmark are documented in [NATIVE-RESOURCE-MANAGER.md](NATIVE-RESOURCE-MANAGER.md).
Same-source catalog comparisons now measure about 3733 ms with script parsing
versus 1138 ms compiled; all serialized indexes and winner maps match across
91 layers. The complete 441-object archived room passes guarded playback.
Correcting stale helper decoder identities and source borrowing reduces player
readiness after world entry from about 3893 to 3118 ms in that workload. These
are measured client improvements, not a native-binary parity claim.

Subsequent native buffer accounting removes whole-graph serialization from
cache charging. Accepted complete-room player readiness is about 2076 ms versus
3024 ms with serialized charging. A fresh-process cold/warm prepared-cache pair
measures 2068/1648 ms; warm deserialization still has 13 prepared evictions.
Original Prelude panel/input timing is now observable read-only, but its room
and boundary are not yet matched to this corpus. Full parity remains unproven;
see the manager reference for conservative budget units, fixtures and gaps.

Passing resource receipts include unit-v8 (35), sync-v4 (41), raw-writer-v3 (13),
prepared-writer-v4 (31), bytes-v5 (15), index-v3 (11), cancel-v4 (13),
textures-v2 (608), mesh-v3 (14), skin-v3 (12), and the catalog benchmarks.
Two strict intermediate animation comparisons fail identically on the previous
checkpoint (`inheritance-prior-v1`); final rig comparisons pass. One optional UI
rejection-layout check also remains unresolved. Do not represent these as a fully
green gameplay/UI suite. The local-v3 reconnect check failed a protocol login
after a streaming abort; menu-v1 reached Main Menu but its probe incorrectly
required the first-entry profile prompt even when a saved profile existed.
The corrected menu-v2 and repeated local-v4 checks pass; later compiled-index
and actor-sharing local checks also pass. Keep the earlier failed receipts.

Rollback starts at `backups/native-remove-menu-shortcut-v1.zip`; incremental
verified checkpoints precede the directory, binding and raw-writer changes.
Create another verified checkpoint before the next architectural experiment.
