# Client keyboard collision queries, 2026-10-20

All live testing remains on the unchanged owned127.0.0.1:5121 Prelude server.
Target native build89.8193.37-17 x64, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
The original binary and game assets remain read-only installation inputs.

The prior adapter used server TestDirectLine371d30 and a conservative circle
approximation. Original client7e6a20 differs: each clipped tile segment performs
its own height bounds, tile polygons84f1f0, area polygons297bd0 and creature
query767740 before advancing. It requires exact result1 from these stages,
then performs optional endpoint traversal7e7210. Its endpoint extension uses
the X-direction sign for both axes; this executed native behavior is retained.
Client coordinate-slot scanning is bounded at32 and differs from truncating
negative coordinates. Polygon297bd0 delegates to297c50 with doorFlag0.

Client767740 uses displayed XY and appearance PERSPACE, inclusive endpoint
distance checks and a private rotating ID-list cursor. It does not apply the
server visibility/death/height/bump filters or the old adapter's moving-away
exception. The port now follows this client query for ordinary player snapshots.
Its native3b0/110/114 owner flags and client630 control bypass are verified in
isolation; those storage fields still require a verified multiplayer replication
adapter. No guessed player-list DM flag is substituted. Complete DM/control,
ghosting and server bump parity are not claimed.

Source client_drive_collision.js contains the three query controllers.
NetworkDriveGeometry projects current area-owned objects and active appearance
tables into private collision records. One input tick prepares those records
once and reuses them across its direct/bisection/slide candidates. The next tick
refreshes positions and radii. No canonical objects or other server resource
contexts are modified; model/geometry caches remain resolver-owned. The input
owner captures its predicted/rendered origins before asynchronous preparation,
and existing area/session/generation guards prevent stale path installation.

Independent original-code observations:

- 512 client7e6a20 cases match ordered lower calls, exact float arguments,
  acceptance gates and endpoint extension. 32 original7e7210 cases match tile
  traversal and exact-result gates. Tile lookup/synthetic clipped surfaces and
  polygon/creature query results are explicitly captured lower providers.
- 234 original767740 cases match vertical/general segment and endpoint circle
  boundaries, ignored ID/type, zero-length lines, isolated bypass flags, missing
  and duplicate lookup IDs, rotating list cursor and lookup order. Allocator,
  object lookup/cast and control getters are captured; native float geometry and
  decision instructions execute unchanged. This is controller validation, not
  a claim that synthetic lower predicates prove the complete physical world.
- Source scripts inspect-native-client-drive-line.py and
  inspect-native-client-creature-line.py; metadata observations are
  native-client-drive-line-v1.json and native-client-creature-line-v1.json.
- 42 focused installed/native movement/scene checks pass. The included
  isolation check verifies two same-name scene contexts use their own radius
  tables, a query retains its tick pose, and the next query sees the updated
  canonical position. Production client-collision-build-final-v1 passes.

Live acceptance is client-collision-live-v3, PID504. The standard six-key check
passes410 translational frames with no stationary translation steps; A/D rotate
in place. The contact scenario first waits for the normal server walk to settle,
requests6/28 orientation, verifies its canonical acknowledgement and then holds
Q/E through production renderer keyboard handlers. It exercises eight partial
timer refreshes and six scaled slide paths. Facing remains fixed; active motion
has its walking clip; final rendered/canonical positions agree within0.05 units.
No failed scene objects, renderer errors or movement diagnostics. Q retains one
17.2ms contact pause; E one8ms pause. This is not flawless-motion acceptance.
Derived strict proofs: creation-performance-client-collision-free-proof-v2.json
and creation-performance-client-contact-proof-v2.json.

Live-v2 is rejected. Its contact harness requested a turn before the approach
had fully finished: canonical yaw297.8 differed from requested292.4. Its contact
verifier also found a final render/server mismatch; no passing contact proof was
created. The harness now requires idle/empty server path and confirmed heading.
Live-v3's bounded controlled authority/sequence/release records are preserved
alongside the rejected case in client-collision-review-v1.json. Broader late-ack
and release timing still deserves checking; no speculative sequence-filter
change was made from the invalid-heading run alone.

The live report reader once raced a passive report write and saw partial JSON;
retrying the same live process produced the complete valid report. Future probe
saves serialize to a sibling temporary file and atomically replace the report.
No process was restarted because an observation timed out or a read raced.

The goal remains active. Remaining work includes the bounded contact pauses,
unmapped control bypass storage and dense-world loading/rendering cost. Earlier
creator/content acceptance and server-isolation requirements remain in scope.

## Local repeat and short-path completion investigation

Client45200, collision-live-v4, repeated the unchanged build on127.0.0.1:5121.
The free-motion check passed401 translational frames with zero stationary
translation steps; A/D remained in-place turns. No failed models or renderer
errors. The contact check exercised six partial refreshes and seven slides,
with fixed facing and matching final displayed/server positions. However,
Q/E contact pauses reached82.5/99.4ms, with19/21 frames displaying the idle
clip while the key was still held. This is not continuous-motion acceptance.
The checker now explicitly reports held idle frames, separately from an idle
clip during an active path; its earlier active-path-only assertion did not
exclude these endpoint gaps. Older accepted proofs retain their limited scope.

Frozen proofs: client-collision-free-proof-v3 and client-contact-proof-v4.
The full live-v4 report closed cleanly and remains outside the incremental
archive; creation-performance-client-ack-input-v1.json freezes only the selected
controlled pose, preceding preview and matching acknowledged endpoint, with
the final source hash. No raw packets/authentication data are included.

Original8001f0 was inspected at the pinned read-only binary and executed with
8114d0/811fc0/804bf0/804840 for four isolated acknowledgement cases. With the
captured pose and short endpoint, zero or matching37 installs that endpoint
and returns to the captured resting animation after48ms of8ms movement steps.
Nonzero36/38 retain the prior path. The replacement motion component matches
the original resulting positions, script flags and completion in all four
cases. Original instructions execute unchanged; collision is explicitly a
clear-line lower provider, rule/model calls and resting selection are captured.
The outer packet reader/input poll are not executed, so this does not establish
the original running game's full hitch duration. Do not suppress valid server
acknowledgements on the strength of this replay. The native input scheduling,
complete path-merge collision branches and timing around acknowledgements are
the next investigation, with control-bypass wire mapping still open.

Reproduction: scripts/extract-local-drive-ack.mjs (only needed to derive the
frozen input from the closed raw run), inspect-native-drive-ack-completion.py,
native-drive-ack-completion-v1.json and
test/network-drive-ack-completion-native.test.js. The Python replay reads the
frozen metadata directly. Initial replay omitted the correction helper from
its execution allowlist and failed; v1 failure log is retained. v2/v3 execute
the complete intended slices successfully. Fifteen focused ack/preview/input
checks pass. The installed geometry rerun also passes both checks; its first
sandboxed attempt was denied read access to the sibling installation.

Client45200 closed normally before the separate sustained local rendering run;
that run also closed normally. Server20964 remains unchanged. Production source
and build remain v19. See renderer-local-sustained-check.md for the rejected
light-reserve hypothesis and measured two-minute local rendering results.
