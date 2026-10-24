# Native cross-server handoff — local round trip verified, test mode only

Native destination preparation and presentation installation are now separate.
`tools/portal-adoption.mjs` connects the proven backend portal protocol to native
lobby/world ownership. Real owned native servers on127.0.0.1:5121 and5122 complete
**A→B→A**, with original character download, source release, fresh destination
login, arrival waypoint handling, animated native gameplay and character saving.
No online game server was connected or queried.

This is a **partial local milestone**. Production native handoffs remain disabled;
only `--portal-handoff-smoke` installs the adoption hook. Native cancellation and
real destination failure/retry are now separately verified in
[NATIVE-HANDOFF-RECOVERY.md](NATIVE-HANDOFF-RECOVERY.md). NUI, server-vault and
NWSync across a handoff still require checks before normal-client adoption.
Full migration, rendering and60FPS acceptance
remain incomplete.

## What changed

`tools/local-host.cjs` now prepares sessions without replacing native services.
The endpoint policy runs **before** installed-session preparation can query the
server. Only sanitized resource/login configuration is retained; credentials
stay private. The existing identity's `forPortal` supplies a separately owned
destination identity, including the portal password. Transmitted waypoint names
and the native seamless fallback are retained. No BIC or credentials go to Godot.

The existing backend43/1→43/2 or43/3 transfer remains responsible for downloading
the character, releasing the source peer and admitting the destination. Native
adoption requires the exact closed/handoff-ready source session and monotonically
advances native connection ownership. It retires old UI/text/action/visual/NUI/
buff/party/particle work, invalidates the world transfer, drains resource staging
and installs fresh services before destination connect publishes state. New
character persistence is bound to the new session **and** native connection.
Resource/text callbacks close over their original session, and diagnostics are
fenced against retired native connections. Asynchronous installation checks its
owner after waits; disconnect waits for in-progress service binding.

Prepared-job records use weak source references. Keeping a destination alive
must not retain every prior server world through a chain of portal jobs. Failure
cleanup can recover either a partially installed destination or the already
released origin. A cleanup exception cannot leave the transfer lobby stuck, and
a late failure cannot clear a newer native connection.

An in-flight particle frame rejected during worker retirement is counted as
retired work, without publishing a failure into the next world. A genuine
current-frame worker error still produces its normal diagnostic and failed
completion. Two targeted tests distinguish those cases.

## Evidence and reproducibility

Installed original server SHA256:
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
No original binaries, Ghidra database, running original client or installed art
were modified. No original art is copied into the fixtures; all models/textures
resolve from installed resources. Source main/dist sentinels remain unchanged.

`tools/create-handoff-servers.mjs` derives two authored modules from the pinned
GodotFeedback1 fixture, using the installed NWScript API's actual ActivatePortal
signature. They have separate profiles, local vaults, publicserver0 and disabled
NAT punching/relay acceptance. The secondary process is managed only when its
binary, exact profile and requested module match. Hashes:

- GodotHandA1: `3fd8dec1830d584f6f2109e580564a4ea16f6ef5860f70823c90f02964e9886b`
- GodotHandB1: `b619a4250152c34de84ccdcc93d67914929a584006477e3d0793b3f6d50e9504`

Fixture report: `reports/handoff-server-fixtures-v1.json`. The test driver
`test-handoff.ps1 -Report <unused-name.json>` checks that both UDP endpoints
belong to these exact owned profiles/modules and opts into loopback5122 only.
It does not start, kill, or connect to arbitrary servers. Ordinary tests retain
the default loopback5121 policy.

`reports/native-handoff-local-v5.json` passes the strict
`tools/handoff-evidence.cjs` gate after real shutdown:

- Three fresh native connections, generations1/1/1, areas dense_a/dense_b/dense_a.
- Two downloaded BICs of40,275bytes, with source closed and handoff-ready before
  adoption. The installed character is read only for the initial connection;
  no destination re-selection/upload of the fixture character occurs.
- Actual native waypoint requests and authoritative destination positions near
  [52,40]. The server adjusted the return position to[52,39.4], within its
  ordinary safe-placement neighborhood; the client did not teleport locally.
- Three animated native presentations with camera following and changed skin
  vertices. **48 dialogue/examine checks**,16 per admission, all pass.
- Three real server character exports persisted under the correct new connection.
- All retired native scene-owner counts are0; worker epochs1/2/3 close with
  pendingJobs0/remainingThreads0. Two backend retirement records report0 threads.
- No rejected commands, game script errors, resource-transfer failures, native
  leaks or live particle-frame failures. Native exit0 and disconnectedtrue.
  Verbose Vulkan overlay naming/registry warnings are retained as warnings.

Screenshots for source, destination and return gameplay were inspected. The
editor was preserved, so this is not a clean performance benchmark. Existing
unsupported wind providers/missing particle bitmap diagnostics are retained;
this milestone does not claim full particle/weather fidelity.

`reports/native-handoff-backend-v5.log`: **84 passing tests** cover existing
IPC/portal-wire/lobby behavior, new native adoption/cancel/failure barriers,
particle retirement and acceptance rejection. The evidence gate refuses partial
travel, stale ownership, missing gameplay/saves/waypoints and surviving workers.
Before-shutdown validation permits only the current particle epoch to remain
live; final acceptance requires all epochs released and actual native exit0.

`reports/portal-adoption-lifetime-v1.json`: an authored4MiB origin is finalized
while its destination and adoption coordinator remain live (`node --expose-gc
tools/portal-adoption-lifetime.mjs --report=<unused-path>`). This proves the
coordinator does not retain that origin, not full backend/engine heap parity.

`reports/native-session-split-local-v1.json` also preserves ordinary localhost
admission, animation and16 dialogue checks after the preparation/setup split.

## Retained failures and remaining work

The first fixture generator attempt used the wrong GIT creature-list field name
in B; A's already-authored outputs were retained. The corrected generator checks
existing files byte-for-byte, validates both modules before writing remaining
outputs and refuses mismatched files. No original resources were overwritten.
Initial launcher v1 split its report argument, failing before startup; its exact
owned Electron PID4916 was closed after inspecting its command line. V2 completed
the trip but exposed a retired-worker diagnostic. V3 fixes that and records
arrival/character details. V4 completed gameplay but failed the newly added
shutdown gate because disconnected was recorded after validation. V5 records
the actual shutdown state first and passes. Failed reports remain unpromoted.

The subsequent recovery milestone verifies native pointer cancellation and real
destination unavailability plus native retry, with successful v6 A-B-A regression.
Next: NUI/window/token and
public-style server-vault reference handoffs, NWSync changes across servers,
then enable normal-client adoption. Add owned-server fixtures and retained
failure/recovery evidence; do not test online until the user reauthorizes it.
The broader atmosphere/sky/weather, rendering/camera and complete migration
checklists remain active. The secondary fixture server is stopped and ordinary
GodotFeedback1 is restored after this batch.
