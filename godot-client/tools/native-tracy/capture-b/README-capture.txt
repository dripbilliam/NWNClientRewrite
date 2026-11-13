PRIVATE Tracy0.13 capture workflow. Root owns native/build/capture scheduling.
No source helper downloads, installs, changes PATH, starts a game or promotes D.

REVISION B: all predecessor A sources and source receipt remain unchanged.
During capture connect/save, exact client lifetime/path and TCP peer ownership
are sampled; actual client/capture established localhost endpoints must match.
Natural client exit is separately recorded and accepted only after ownership was
observed and its exit is clean; attribution ends at that observed exit. Replaced
listeners, failed/unknown retirement and missing connection witnesses reject.
Only owned capture/export children are terminated on timeout. Pipe drains have a
5second Task.Wait bound, failures are recorded before rejection; no unbounded
GetResult follows a timeout. Partial logs/traces remain failed evidence.

Version: official v0.13.0 commit e6b9ea460993a6f093283055ef3c98025b19f909,
protocol76. Official windows-0.13.0.zip SHA3872f4644c2d8f973076484314b189795e4b67d56b13778fe8ab9c2fea4024fb.
Use fetched root vendor receipts and portable tracy-capture.exe/csvexport.exe.
0.13 exporter has NO -V switch. Provenance comes from pinned release receipts,
executables/source/version/protocol headers plus actual handshake/readback.

capture-plan.cjs source-check reads provenance only. prepare requires root-built
private client exact path/hash +opaque build receipt/hash, required zones file/hash,
fresh label, nondefault port, bounded seconds. Copies workflow/evidence only.
Client build proof is pinned; root builder independently verifies same SDK/client.
No execution is performed by prepare. Capture arguments are localhost-only,
duration1..60s, no overwrite flag, memory percent1..5 (NOT MB). An outer process
watchdog covers connection +save because capture -s begins AFTER handshake.
Private-memory/working-set, trace/export bytes and exporter duration are bounded.

Frozen capture-run.ps1 requires existing exact client PID/FILETIME/path/hash and
TCP listener owning PID before starting capture. It owns/cleans only its own
capture/export processes; game is never killed. Private source/client hashes and
child clean natural exit are recorded. Artifact absence/failed protocol or
instrumentation/forced deadline/memory closure is rejected and retained.

CPU aggregate+self+unwrapped event TSV and GPU event TSV are read back through
official0.13 exporter. TSV chosen because exporter does not quote CSV fields.
Embedded tab/newline rejects rather than silently corrupting table columns.
Open negative-duration CPU events are preserved/count separately, never treated
as completed timing. Required zones need actual positive completed events and
explicit CPU-thread coverage. GPU false for headless initial proof; later true
requires actual GPU events, not CPU render-thread zones. GPU export has no thread
column in0.13. Native .tracy artifact is primary, tables are analysis supplements.
Inclusive CPU zones overlap; don't sum parent/child or CPU+GPU durations.

Expectations JSON:
{"cpuZones":[{"name":"Main::iteration","minimumEvents":2}],
 "minimumCPUThreads":2,"minimumSpanSeconds":1,"maximumSpanSeconds":30,
 "differentThreadZones":[],"gpu":{"required":false}}
Use exact instrumented deterministic worker/render names once those sources seal.

Official sources:
https://github.com/wolfpld/tracy/releases/tag/v0.13.0
https://github.com/wolfpld/tracy/releases/expanded_assets/v0.13.0
https://github.com/wolfpld/tracy/blob/v0.13.0/capture/src/capture.cpp
https://github.com/wolfpld/tracy/blob/v0.13.0/csvexport/src/csvexport.cpp
