# Drive collision spatial candidate

The candidate is implemented and functionally checked, but **disabled by default**. World.drive_spatial_enabled defaults to false. Set it before World.open() only in an explicitly selected comparison. snapshot.drive_collision_route records legacy or indexed-experimental.

Default drive_collision.gd is byte-identical to the dirty-before owner: SHA256 0b49304d86a356439c7adbf465ed5e6c7d93cdd32ab1fd79a689811e7a1b6c56. Its full/delta warm-dirty behavior remains. The candidate lives in drive_collision_indexed.gd; production imports no test fixture.

## Geometry and ownership

drive_spatial_index.gd is a CPU-only RefCounted balanced XY AABB tree. It stores numeric bounds, IDs, two lifetime witnesses, revision, source order and local sequence. No live Nodes, received dictionaries, geometry or gameplay state enters the index. Scope uses the actual World instance ID, generation, area ID and an internal epoch; reset invalidates old tickets.

Static PWK/DWK source positions are indexed by model group. Prepared model arrival publishes local bounds and conservative maximum horizontal footprint once, without transforming or republishing every user. Queries reject retained group bounds, search overlapping position trees, then compute/cache nearby exact world bounds before precise triangles. Known large geometry is never truncated to the legacy 12-metre pending neighborhood. Unknown geometry retains that pending rule; known empty/open DWK contributes no precise obstacle.

Creature bounds include two metres of broadphase slack. Every motion publication updates its exact narrow-phase center. The tree reinserts only when that current personal-space circle no longer fits the retained bound. Slack creates false-positive candidates; it does not enlarge the circle used to block movement.

Noninteractable obstacles remain included. Radius override excludes creatures as before. Pending, creature, floor and object checks retain their prior order; matched sources sort by actual desired order. The original capsule/polygon narrow phase is unchanged.

Original NoNonWalkPolysDetailed at 0x140297c50 scans retained geometry arrays and cached bounds, rejecting XY/Z boxes before reading faces. See NATIVE-DENSE-COLLISION-BINARY.md and reports/native-dense-collision-binary-v1.json. Balanced indexing is our adaptation, not a claim about the original binary.

## Publication and lifetime

Actual World full/delta, movement observation, motion advance, adoption and retirement boundaries call explicit candidate sync methods. Full/table publications batch tree rebuilding synchronously. Individual updates remain incremental. No query sees partial publication; there is no frame-spanning global readiness barrier.

If either received nativeLifetime/clientKnownLifetime exists, both must be valid. Sources with neither use a disjoint private-local admission witness, never claimed as received/native provenance. Scope, ID reuse, removal, revision and asynchronous model callbacks are fenced. Geometry withdrawal keeps a live source lifetime; retirement prevents same-life revival. Open/reclosed doors therefore work without rebinding lifetime.

Queries do not scan world.desired, demand resources, build descriptors or triangulate distant sources. They enumerate M retained model-group bounds, then selected trees. M can approach N for all-distinct models; adapter complexity is not globally O(log N). The retained-flat diagnostic shares the same narrow phase and is not the candidate default.

## Evidence and reproduction

- Pure index v6: 48,521 checks, including 600 seeded independent brute-force candidate/order comparisons and 600 independent triangle/circle/pending comparisons. Covers balancing, bulk/nested publication, native centroid sort, withdrawal, revision, ID reuse, negative/large bounds and detachment.
- Actual World adapter v8: 213 checks against byte-preserved legacy query/path code. Includes first blocked reason, door state, movement, noninteractable PWK, known large geometry, far source/model arrival, type change and stale callbacks.
- Existing collision/path fixture v2: 12 checks against the explicitly selected indexed owner. No installed-resource samples were requested in that run.

Current proofs live under .cache/native-drive-spatial-index; reports/native-drive-spatial-index-v2.json pins exact inputs and evidence. Each copied child is bounded to 65 seconds/2 MiB, exact engine and source/copy/config/descriptor/extension guards, six native-output hashes and protected process identities. No network, graphical rendering, native extension load, native build or user process action occurs.

With an approved idle headless lane and fresh labels:

    & godot-client/tools/test-native-drive-spatial-index.ps1 -Run fresh-index-label -Case index
    & godot-client/tools/test-native-drive-spatial-index.ps1 -Run fresh-adapter-label -Case adapter
    & godot-client/tools/test-native-drive-spatial-index.ps1 -Run fresh-collision-label -Case collision

First failures remain preserved in their original labels.

## Performance scope

The first incremental adapter passed correctness but was rejected for boundary cost: authored full 2,001 rows took 385.255 ms versus 27.842 ms without indexing; one model updating 2,000 users took 391.316 ms. Bulk building helped but still republished every user.

Final position-group adapter v8 observed these CPU diagnostics:

| Operation | Milliseconds |
| --- | ---: |
| Full authored receive without candidate | 30.903 |
| Full authored receive with candidate | 157.545 |
| Initial static tree build, included above | 28.167 |
| One prepared model, 2,000 users | 0.022 |
| Legacy 2,001-row query factory | 57.622 |
| Candidate query factory | 0.023 |
| 40 candidate near clear calls | 3.132 |
| 72 creatures over 60 motion syncs, total | 8.362 |
| Actual far-source delta | 0.183 |

These single isolated authored diagnostics are not a native movement oracle, steady FPS result or matched loading benchmark. Full publication still adds substantial synchronous CPU. Dense replay must measure entry, control readiness, total load, selected route and walking under streaming before promotion. Default runtime remains legacy. No performance-goal completion or pixel parity is claimed.
