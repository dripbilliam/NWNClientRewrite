# Runtime diagnostic recording — 2026-10-12

This is replacement-client instrumentation, not a newly inferred native game
logging contract. No binary or Ghidra changes were needed.

## Recorded occurrences

The complete journal is independent of ModuleSession's 64-message HUD buffer.
Every record has a schema version, session identifier, sequence, UTC timestamp,
category, severity, message and copied context. Module/area, canonical uint32
object IDs, source placement, tag and resource identifiers are included where
the caller knows them. Binary asset bytes are represented only by byte counts.

- NCS engine calls with no handler, and handler failures, are recorded in the
  VM before propagating ScriptError. Metadata includes API name/index, script,
  instruction PC, OBJECT_SELF, and typed object arguments. Inspection does not
  pop arguments or capture an action. Scheduler/session catches preserve the
  record identity; a later execution records another occurrence.
- Known incomplete supported adapters emit `engine.partial` when called.
  Their limitations remain explicit rather than being reported as missing
  handlers. Supported runtime behavior is unchanged.
- Missing resource lookups, failed BIF reads, game/module indexing failures and
  absent HAKs are recorded at the resolver boundary. Lookup probes are
  informational: TGA may be absent while DDS or PLT succeeds. Consumer-level
  omissions and decode failures are separate records.
- Scene/model, texture/palette, WOK/PWK/DWK, appearance, creature/attachment,
  animation/supermodel/binding, skipped binary model features, UI/font/portrait,
  talk-table and audio failures are recorded at their relevant boundaries.
  Known stat-provider limits are recorded on character import. Failed local
  interactions, console warnings/errors and UI/radial placeholder requests are
  retained. Unexpected renderer exceptions/rejected promises are captured.
- The Electron main process independently records failed page loads and
  renderer process exits, including cases where the renderer cannot report.

Animation binding omissions are recorded once per animator/clip/node, and a
missing talk-table reference once per GameText instance/reference, rather than
once per animation frame or HUD refresh. The normal renderer loops still run.
Scene omissions are recorded on each load. All journal records are retained;
the visible recent-message list is only a preview.

## Persistence and inspection

Electron creates a distinct ignored `runtime-logs/runtime-<timestamp>-<uuid>.jsonl`
file for each application run. The sandboxed preload exposes only the fixed
log-location and append operations; the renderer cannot choose a file path.
The writer validates batches, appends JSONL and fsyncs before acknowledging.
Retries use session/sequence identity to avoid duplicate acknowledgements.
Normal window close requests a renderer flush before closing; a five-second
timeout records a close-flush failure instead of hanging the application.

The browser adapter stores the same records in IndexedDB
`nwn-runtime-diagnostics`. Saved sessions remain after reload. Tools → Runtime
diagnostics displays the current count, pending queue, destination and save
errors, with session export and retry controls. Browser mode additionally
exports previously saved sessions. Export includes all current records, even
ones whose persistence failed; a failed save keeps its queue and records the
failure. Native logs remain ordinary files for later inspection.

These are observed failures and limitations. Unvisited script branches do not
generate fake occurrences. Logging does not resume an aborted script, load
missing assets, implement the missing calls or resolve gameplay startup. An
abrupt process/machine termination can lose unacknowledged in-flight records;
acknowledged native batches have been fsynced. A single native IPC record is
limited to 1 MiB; a rejected batch is retained for export/retry, not truncated.

## Validation

130 tests pass. Diagnostic coverage checks direct VM failures and supported
handler rejection, canonical ID zero/high-bit object references, scheduler
deduplication, repeated occurrences, the short HUD/full-journal distinction,
resource fallback/read failures, swallowed walkmesh omissions, missing TLK
fallbacks, concurrent persistence, save failure/retry, safe metadata snapshots,
and durable JSONL validation/acknowledgement identity.

Production Vite build passes. The existing large-chunk warning remains.
The real bundled Electron renderer passed:

- `modulestart001 --check-progression --check-diagnostics --full-scene`: real
  startup retained level 1 / XP 0 / HP 5 and its cutscene lock. The 3,276-record
  file and downloaded export matched the full journal, including `CopyObject`
  at `ww1_start_onent@0x245` and `EffectDamage` at `@0x7d9` with module/self/PC
  context. The opening is still incomplete.
- `angmarshouse --check-radial --check-diagnostics --full-scene --play`:
  exploratory fixture explicitly disables startup, opens/closes a real door,
  checks radial families and retains unsupported requests. All 1,681 records
  matched the file and export. `fxpa_cloud02` and four object walkmesh omissions
  are individually recorded, alongside their lower-level lookup attempts.
- The same radial fixture with `--browser-diagnostics` omitted the preload and
  used real IndexedDB. All 1,681 records exported correctly; reload retained
  them and added the new session-start record (1,682 total stored).

Reports and visually inspected screenshots are under ignored
`backups/animations/diagnostics-verified-*`. Implementation is generic to any
selected module/resolver; the installed module here is a validation fixture.

## Follow-up

Resume the shared class/feat/skill/stat validation work in the roadmap. Use the
persisted categories and script locations to choose subsequent engine slices.
Canonical cloning/item lifecycle and damage remain real startup blockers;
this diagnostic milestone does not change their priority or bypass them.
