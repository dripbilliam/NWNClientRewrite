# UI preparation cancellation and startup check

The complete graphical MenuCheck now finishes inside its original20-second
watchdog. `native-ui-cancel-startup-v1` passed Main/Options/Player Name/browser
routes, original artwork readiness and the separate model/UI preparation
start/cancel checks. It made no network connections. This supersedes the
functional timeout in the previous profile milestone for the tested catalog;
it does not certify full original UI parity or general cold-loading performance.

The defect was in the native catalog ownership boundary. UI/model preparation
controllers set their own stop flag, but `session_catalog.prepare()` continued
mounting every selected Workshop/HAK/manifest/directory and building the final
lookup index. Returning to the idle controls therefore waited for unused work.
The full startup exercise runs several independent catalog owners, making that
delay much larger than a single menu's presentation.

`session_catalog.gd` now accepts an optional native cancellation guard. Its
asynchronous owner supplies a mutex-protected flag and checks it before work,
between mount steps and before/after final index publication. Cancel is
nonblocking; Close and retirement request cancellation before joining tracked
workers. A fresh Start resets the flag only after the previous worker is joined.
Canceled current owners get an explicit canceled result; retired owners cannot
publish a late catalog. Calls to static `prepare(sources)` without a guard retain
their existing normal resource order and index behavior.

Both `native_ui_preload.cancel()` and `native_asset_prework.cancel()` now forward
the request to an active source loader. Model preparation's separate background
process already receives cancellation controls, so it benefits from the same
native boundary. Clear also cancels pending discovery before clearing prepared
data. Completed menu images/data remain saved. The current individual file read,
archive parse, manifest helper call or directory scan still finishes; this does
not asynchronously interrupt parser/file internals or claim bounded latency for
every possible individual resource.

The menu check retains phase markers in its final native report and
`RUN.native.json.menu-stages.jsonl`, including when the full test fails. In the
accepted run the trace took9.206 seconds after the entry probe began:

| Phase | Trace time |
| --- | ---: |
| Main/Options/Profile/browser routes and artwork ready |5.957s|
| Model cancellation requested |6.112s|
| Model cancellation completed |8.137s|
| UI preload cancellation requested |8.159s|
| UI preload cancellation completed |9.206s|

Those are functional-check phase observations, not an FPS benchmark, a
from-process-launch startup measurement or a matched cold-cache speedup claim.
The full pregame catalog still mounted90 layers, including66 global Workshop
HAKs and290,068 lookup entries. Its mount took5.416 seconds in this run; other
unrelated loading/preparation and the original binary's speed remain open work.
The watchdog and graphical-art gate were not relaxed.

Current receipts:

- `native-catalog-cancel-v2`:13 offline original-resource, poisoned later-archive,
  canceled partial-index, asynchronous restart and retirement checks.
- `native-ui-cancel-startup-v1`:all7 native entry-route checks, original artwork
  readiness, both independent preparation/cancel flows, normal native exit0,
  workers joined, source unchanged and public connections0.
- `native-ui-cancel-local-v1`:seven native admission checks through profile and
  Direct Connect followed by170 authoritative checks against the isolated
  original local server127.0.0.1:5125. The test server was released afterward.
- `native-ui-cancel-preload-cold-v2`:24 actual UI preload, original/unbaked pixel
  equivalence, persistent save/reuse, bounded working set and cancellation checks.
- `native-ui-cancel-preload-warm-v1`:21 fresh-process reuse/cancellation checks
  against the same isolated temporary cache. Unopened saved menus render no new
  pixels on this path. The existing four explicit legacy reader/font issues remain.

All accepted debugger receipts have unchanged pinned source, normal heaps and
no trapped exception, script error or lifetime leak. Graphical launches used the
secondary monitor without taking focus or moving/capturing the physical pointer.
The original NWN client and other applications were preserved.

Failed diagnostics are retained. The first cancellation test compared equivalent
Windows paths with different separators; normalizing its fixture assertion fixed
that check. The first cold-preload invocation incorrectly put its prepared cache
under the source workspace. The existing protection refused to start it; the
old test then assumed a canceled-state field and hit a script error. Only its
identified test processes were stopped. The accepted cold/reuse runs use the
required external temporary cache. Neither failure is counted as accepted work.

Full-resource UI parity, original-client comparison at relevant scales, the
remaining browser/connection/creation/HUD/gameplay/NUI surfaces and the complete
UI action/state ledger remain required. General game porting stays deferred.
