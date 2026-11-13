Tracy CPU integration — private diagnostic client, 2026-11-08 (UTC-5)

The normal engine/DLL selection remains accepted D. The validated cache-directory
script fix is applied to current source and the fresh private package below.
The private diagnostic is source-equivalent D with MSVC/PDB symbols, Tracy0.13.0,
one engine-owned Tracy client and a native-DLL bridge. All16 current options stay
selected. The private package is .cache/native-tracy/live/manual-cache-a.

From godot-client, open the ordinary menu with:
  pwsh -NoProfile -File .\tracy-client.ps1
Choose Arelith and log in normally. No automatic login or server join is added.
This stage keeps its one launch history; do not erase launch evidence to reuse it.

Once in an area, capture a short idle/movement/camera interval with:
  pwsh -NoProfile -File .\tracy-capture.ps1
Default3seconds after a3-second delay to refocus the game; -Seconds accepts3..8.
The capture attaches only to the verified
private native PID/path/lifetime and localhost port48135. It never closes the
game. Official0.13 tools save/reopen .tracy and export summary/self/CPU tables.
Outputs use fresh timestamps under .cache/native-tracy/captures/arelith-*.
The default is short because full per-event CSV exports can be much larger than
the compressed trace. Memory/file/time bounds reject oversized captures.

Use vendor/windows-0.13.0/tracy-profiler.exe to open a saved trace (full path starts
at .cache/native-tracy/). Do not attach its live viewer while CLI capture is active.

Validated locally:
- Client world/session scripts compile, startup capability contract and real
  32-lamp/settings/native-owner checks pass.
- Headless8s capture:24,705 completed CPU events, named main/worker/native zones,
  balanced bridge scopes, no invalid/overflow/live scopes and natural exit0.
- Forward+ Vulkan separate-render-thread fixture:64 original-textured emitters,
  135 checks, positive pixel contribution,1,210,307 completed CPU events and
  render drawing on a different captured thread from main submission. Exit0.
- Both real traces reopen through matching official0.13 exporters.
- The original accepted EXE, DLLs and descriptor verify. The updated script closure
  is pinned separately to the cache-directory fix acceptance.

GPU timestamp zones, automatic stack sampling and memory/system tracing are not
enabled in this first integration. Render zones measure CPU work, not GPU time.
Tracy compressed thread IDs are not OS thread IDs or measured core utilization.
Script call-site/callee zones may share a name: use source location and self-time;
counts alone do not show duplicated game work. Parent/child inclusive times overlap.
The graphical fixture was deliberately capped20FPS. Instrumentation and a compiler
change make this diagnostic unsuitable for claiming a clean FPS improvement.
The previous manual-source-d Arelith session is reviewed in arelith-review-a.
The new cache fix has passed headless checks in both normal and Tracy engines;
its FPS effect and a fresh Arelith session have not been measured.

Exact current acceptance: live/manual-cache-a/native-acceptance.json in that cache.
Accepted local traces: captures/headless-wire-b and captures/graphical-wire-a.
Failed A/B build/capture records and partial manual-source-c remain explicitly
unaccepted; the active private package is manual-cache-a only. Previous stage D
and its Arelith capture remain retained evidence.
