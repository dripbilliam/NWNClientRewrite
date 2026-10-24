# Keyboard collision projection cache, 2026-10-20

The old NetworkDriveGeometry obstacle key serialized complete replicated,
static and light-state records. An unrelated HP/effect/inventory change thus
invalidated every cached placeable/door polygon. This was avoidable client
CPU work on a movement preview tick, not a server authority requirement.

The key now contains the exact physical inputs read by the existing adapter:
membership, objectID/type, resolved position/orientation, placeable appearance,
or door type/generic type/open state. Records snapshot their poses before an
asynchronous mesh read. Per-tick creature positions/radii still refresh through
the existing independent query projection. Resource caches remain scene and
resolver owned; no canonical server object is changed. A physical update still
rebuilds the same native collision store and uses the same queries.

Thirty-one focused checks pass, including installed WOK/PWK/DWK queries,
server-specific radius isolation, snapshot ownership, door and placeable
invalidation, repeated input timing, slide searches and acknowledgement/path
completion. The new regression reproduces nonphysical traffic without a
polygon rebuild and observes every tested physical change.

An alternating100-iteration synthetic CPU benchmark uses300 six-vertex/four-
face placeables. It compares the exact sealedv25 method against current code,
mutating HP and effect lifetime each iteration. After ten warmups, prior
median/p95 is0.946/1.678ms; current is0.075/0.102ms. Mesh-provider calls fall
from30600 to600, including initial preparation and a final physical move.
Both final stores have identical IDs, vertices, indices and bounds. This is
not an end-to-end FPS, live hitch or original-binary speedup comparison.
Reports retain both source hashes and timings; no assets or credentials are
in the workload. The prior source comes from the verifiedv25 archive.

Additional read-only native review does not justify masking short-path idle:
NWN:EE89.8193.37-17 x64, pinned SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
`0x1408114d0` completes a path by clearing acceleration/script state and
selecting the resting animation, consistent with the existing four-case
original-instruction acknowledgement/completion oracle. `0x1406f1bc0` adjusts
the wire timer at UI+0x1a0 using the shortened-path fraction. `0x1406ea9e0`
builds its target from path-position+0x2c0, consistent with current code.
Successful REA reports rea-held-drive-path-complete-v1,
rea-held-drive-short-timer-v1 and rea-held-drive-preview-positions-v1 retain
these containing functions. Exact individual call-site addresses were not
newly resolved in this review; no whole native input/render-loop claim.

The current production build is index-DnQV5M3h.js; built main-v6 verifies menu,
portrait IPC and missing/invalid resource behavior with no joins/content
fetches, cancelled debug font requests and no renderer errors. The open local
gameplay client is left untouched. Physical-key feedback, residual short
contact pauses and broader live performance acceptance remain outstanding.

Final follow-up also fixes an asynchronous creature-membership race: each query keeps its captured ID list and iterator while the next tick starts from a fresh snapshot. The exact prior v25 query reproduces an old blocked ray becoming clear solely because a newer query removed the blocker; current code keeps the old query blocked and correctly lets the new query through. Addition/removal regression assertions pass. Final31 focused checks-v3, production build-v2 and built main-v7 index-CcEowr6S.js pass. Final benchmark-v2 hashes the exact source with both repairs: median 0.931ms prior/0.073ms current, p95 1.732/0.121ms. Read counts and final geometry equivalence remain unchanged. Probe drive-query-membership-v1 and cache-proof-v2 retain the reproduction and scope; no claim that all live contact stutters are fixed.

Checkpointv26 independently verified:1388files/60565926bytes,SHA256ecbd4a8d94046de189fdd949746b96f946f71080ff408ca94b0c6cdde92ada26;54parents/211required entries, zero missing/newcredential candidates. This verification note is post-seal.
