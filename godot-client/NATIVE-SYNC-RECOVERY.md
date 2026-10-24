# Native recovery during destination content loading

Native cancellation and required-content failure now pass combined local server
transfer tests. Source menus/world retire before the destination is admitted;
the destination download can be cancelled through the actual native button,
and a failed required download shows a content error with usable cancellation.
Pointer Connect then starts a fresh, animated admission. These tests use only
two owned loopback game servers and loopback HTTP repositories. No online game
server was queried or connected.

## Accepted evidence

`reports/native-sync-cancel-local-v2.json` and its `-cancel.json` child pass:

- Real A→B handoff downloads the40,275-byte character and releases the source.
  B starts its distinct NWSync manifest; native progress is observed at4/15.
- All **18 native recovery checks** pass. Play stays disabled; actual Cancel
  works, connection2 becomes menu3 and pointer Connect starts connection4.
  The source world/NUI owners are freed, no destination world opens, late
  progress is rejected and the recovered menu clears its error/busy state.
- B's HTTP trace contains completed initial data requests and aborted in-flight
  requests. Its13 requests include the manifest; no completed B admission occurs.
- Source and retry complete two animated native admissions,32 dialogue/examine
  checks, **14+17 NUI checks**,30 mounted resource checks and two character saves.
  The source A manifest is reused with no additional HTTP requests. Old B-only
  resources remain unavailable, and native menu pixels match A.

`reports/native-sync-failure-local-v1.json` and its `-failure.json` child pass
the same18 recovery,32 dialogue and31 NUI checks. The loopback repository serves
the real B manifest, then returns404 for required data. Its five requests include
one manifest and four failed data requests. The native lobby reaches
`resources-unavailable`, explains the content problem, and remains cancellable.
Pointer Cancel/Connect recovers through menu3 to fresh connection4; the failed
destination is never admitted.

Both native reports verify the prepared destination closes, its private BIC is
wiped, and joining remains blocked during cleanup. Each new destination actually
attempts one peer connection. Decoded advertisement hashes are recorded **at
receipt**, before resource resolution can be interrupted by cancellation. The
existing session emits its normal `server-resources` event after resolution;
that later event cannot prove receipt for a cancelled download. The test wrapper
observes decoded hash metadata without changing parser/session behavior or
exposing credentials, paths, URLs or BIC bytes to Godot.

Both runs exit0/disconnectedtrue with zero retired native survivors, no pending
NUI resources and both admitted-world particle epochs closed with no jobs or
threads. B never prepares a world or particle worker epoch. The native observer
uses a weak reference from recovery to its parent and disconnects on shutdown.
Pending/error/recovered screenshots were inspected. Existing particle bitmap/wind
and Vulkan loader diagnostics remain separate; no full rendering claim is made.

`reports/native-sync-recovery-backend-v1.log`: **180 passing tests**, including
the previous portal/NUI/vault/NWSync regressions, strict combined recovery gates,
private-character/epoch/resource/stale-input checks, and actual loopback HTTP
failure injection/removal. Pre-shutdown validation permits only current retry
workers to remain; final acceptance requires actual shutdown and complete cleanup.

## Reproduction and retained failure

`node godot-client/tools/test-sync-handoff-local.mjs --scenario=cancel --report=<unused.json>`
and `--scenario=failure` create fresh private caches, manage only the exact owned
game-server profiles, run native controls, close both HTTP servers and restore
ordinary GodotFeedback1. No original game/editor is closed or modified. These
are functional checks alongside the preserved editor, not clean FPS benchmarks.

Cancelv1 completed all18 native controls and animated retry but failed its initial
gate. The gate incorrectly expected a particle epoch for the never-admitted B
world and expected the post-resolution advertisement event during cancellation.
The corrected gate requires the actual two admitted world epochs, plus separate
receipt-time advertisement evidence for connections1/2/4. Cancelv2 supplies that
evidence and passes. The failed report is retained and not promoted.

Content replacement/cache behavior remains documented in
[NATIVE-SYNC-HANDOFF.md](NATIVE-SYNC-HANDOFF.md), with ordinary peer cancellation
and rejection in [NATIVE-HANDOFF-RECOVERY.md](NATIVE-HANDOFF-RECOVERY.md), and both
reference variants in [NATIVE-VAULT-HANDOFF.md](NATIVE-VAULT-HANDOFF.md).
Normal-client activation is a separate following change with regression checks;
this checkpoint still retains the test-only adoption switch. Full migration,
public-server acceptance and sustained moving-scene60FPS remain incomplete.
