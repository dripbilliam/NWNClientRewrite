# Persistent asset prework

Open **Main Menu → Options → Prework** in a newly started native client.
Choose the installed game, an already-downloaded server content set (identified
by its local module label), or the current connected server, then choose a scope
and press **Prepare assets**. A server connection is not required for installed
or downloaded content. Local metadata is discovered in the background; native
NWSync databases are opened read-only. Each downloaded content set mounts
separately, preserving its resource precedence instead of mixing servers.

- **Current session appearances** saves the model preparation requests seen so
  far, including equipment/palette variants, plus finished artwork from opened
  UI panels. Open the panels you want to save before starting.
- **All available models + current appearances** also prepares the mounted
  catalog's model names on both static and relevant-animation routes. This
  includes installed resources and available server content; it can take much
  longer and consume substantial disk space. It does not download new content
  or enumerate every possible character/item color combination.

Before joining, the menu defaults to downloaded content when present and the
all-models scope. Missing downloads are reported as unavailable assets; prework
does not initiate a server connection or fetch missing files. Current-session
appearance and opened-panel coverage grows after actually using those assets.

**Workers** defaults to Automatic (up to four, leaving a logical processor
available when possible). Choose 1, 2, 4 or 8 to control CPU/memory usage. The
workers also share disk bandwidth; eight workers need not outperform four,
particularly while saving large bundles. The setting persists and can change
during preparation: increasing it fills extra
slots immediately; decreasing it lets admitted work drain before refilling.
The total admitted model/image-save work stays within that limit. Progress
shows active workers and completed items per second, with updates throttled to
avoid rebuilding the UI for every completion. UI/GPU image access stays on the
main thread; at most one finished UI image is captured per frame.

The normal client runs preparation in a separate headless Godot process. Only
JSON progress/control messages cross back to the game; model graphs, textures,
catalogs and native handles stay in that background process. Saved appearance
options and opened-panel artwork use data-only binary packets so integer types,
pixel bytes and GUI bounds remain exact. Preparation asset services return
status-only packets and release their unused private model graphs on workers.
They do not fill an additional session cache with assembled models that no
renderer in the preparation process needs.

Changing Workers updates the background process. Cancel drains it; Clear waits
for it to exit before deleting output. A frontend heartbeat cancels abandoned
jobs, and disconnect/quit retires the owned process. A worker crash is reported
in the Prework tab while the client remains open; completed cache files remain
available. Diagnostic status and the worker engine log stay in its private
temporary job directory, with the log path retained in the session report.

Preparation is explicit. Normal asset requests reuse saved results but do not
silently populate this new prework store. The existing lower-level decoded
resource caches continue operating separately. Progress counts preparation
operations, including reused variants; unavailable assets are counted and the
last error is shown. **Cancel preparation** stops admitting work and drains the
active workers, keeping successfully saved results.

Progress names the oldest active job and its elapsed time, rather than the last
job queued. The last issue names its own model and static/actor route; it can
refer to a different job than the one still running. Slow jobs (at least one
second) and failures are recorded in `model-diagnostics.jsonl` in the worker's
temporary job directory. Hovering over progress shows that path. Records include
worker duration, decode/rig/texture/save phases and saved-file write timings.
These observations do not establish a general throughput improvement.

Deterministic ASCII format/hierarchy failures receive small saved rejection
records. A later explicit preparation validates their source and dependencies
and skips repeating the rejected work. They still count as **Unavailable**, with
the original error, and the UI reports how many known issues were skipped.
Changing the model, an inherited dependency, options or processor identity
retries it. Transient missing-resource/I/O failures are not memoized. Clear
removes rejection records together with successful prework. This does not repair
unsupported/malformed source models or remove first-run disk-write pauses.

**Clear saved prework** drains this preparation action and deletes its generated
files. It preserves installed game files, server downloads, unrelated files,
the existing lower-level decoder caches, and resources already loaded in RAM or
GPU memory. A cancelled/cleared job cannot publish an old-generation result
after the clear. Starting preparation again is a separate explicit action.

**View saved files** opens the dedicated `saved-prework-v1` directory in the
system file manager. It also creates that directory if no preparation has run
yet. The button remains available during preparation.

## Stored data and invalidation

Files live in `saved-prework-v1` beneath the launcher's native prepared-cache
directory (normally `user://native-prepared-v2`). This is outside the repository.
The prework store contains checked, data-only native cache entries:

- Assembled model bundles: decoded model data, prepared mesh/skin upload arrays,
  inherited animation/rig data, decoded texture/palette data, and dependencies.
- Finished UI/item artwork that was rendered in the session: RGBA pixels plus
  the exact raster/layout bounds. Later sessions skip its model installation,
  viewport rendering and GPU readback, but still create/upload its texture.

Worker reads validate the actual source/dependency bytes, selected raster format,
optional-resource presence and recorded missing-texture decisions. Palette,
supermodel, source model, appearance-option and content precedence changes cannot
reuse an incompatible result. Engine version, processing settings and prework
schema identify entries too. Development source fingerprints additionally
invalidate results when native data/render processing code or its compiled
extension changes. Exported builds must bump the explicit schema revision when
changing preparation behavior if development source files are absent.
The v1 cache-management and source-discovery fingerprint slots retain their
original identities: changing worker scheduling/locking or local discovery does
not discard compatible prework. Decoders/render processors remain fingerprinted,
and all actual resource dependencies are revalidated.

Independent saved files serialize, checksum and write concurrently. Writers
for the same destination share a per-entry gate. Clear advances the generation,
blocks admission to that directory and drains active publications before
deleting generated files; an old queued writer cannot recreate cleared data.

Corrupt or outdated derived data falls back to the original preparation path;
another explicit preparation action repairs it. GPU resources and private scene
nodes are still created in each session. Animation, lighting, effects and world
state remain runtime work. No sustained FPS or Arelith-wide speedup is claimed.

## Validation

`tests/native_asset_prework_test.gd` runs in cold and warm modes with the same
private temporary fixture but **two fresh Godot processes**. It checks explicit
Prepare/Clear controls, exact graphical icon pixels/bounds across processes,
model bundle reuse, the faster session memory tier, changed texture and
supermodel invalidation, optional-resource changes, corruption repair, cancel,
scoped deletion and rejection of late saves. It makes no public connections.

`tests/native_asset_prework_original_test.gd` separately checks installed original
inventory-button up/down/hilite artwork against byte-exact cached results using
fresh catalogs, resource pools and icon owners.

`tests/native_offline_prework_test.gd` exercises the disconnected graphical
Prepare control, offline catalog loading, persistence/reuse, cancellation and
clearing while indexing, and connected/disconnected source changes. Native
NWSync tests cover manifest discovery/deduplication using authored SQLite/file
caches. The actual launcher menu check also verifies that disconnected prework
is enabled, starts indexing local content and cancels without a server login.

`tests/native_prework_workers_test.gd` compares actual one/four-worker processing
of the same authored model corpus, checks identical persisted output and actual
background threads, and exercises live worker changes, cancellation, flushing,
and View saved files routing. Barrier-controlled writers prove concurrent saves
for independent entries, serialization of duplicate destinations, draining and
generation invalidation during Clear, and release of all publication leases.
An optional bounded read-only probe checks compatibility with existing local
prework. Its timing samples do not establish an Arelith-wide speedup.

`tests/native_prework_rejections_test.gd` uses two fresh processes to check saved
failure reuse, error/model/route attribution, active-job tracking, root and
supermodel invalidation, successful repaired output, and flushing rejection
records. `native_ascii_resource_diagnostics.gd` inspects selected original local
resources without making a server connection. The Arelith sample reproduced
the hierarchy rejection in `ashlw_032` (a duplicate node with its own name as
parent) and the array-count rejection in `atj01_g12_04` (a control character
where a line break would normally separate the count and first vertex). Their
intended original-engine behavior has not been established; parsing guards
remain in place.

`tests/native_prework_process_test.gd` checks actual process isolation, exact
persisted model/appearance/icon output, live worker changes, cancel and Clear.
It deliberately terminates an owned worker and verifies that the frontend
survives and completed files remain. The extended isolated menu check processes
real locally downloaded Arelith content without a server connection; cold
checks use a private temporary prepared cache. `native_prework_corpus_test.gd`
is an offline bounded diagnostic for comparing the in-process path.

The in-process eight-worker client path produced native heap-corruption exit
`0xc0000374` during investigation. The exact native corruption site has not been
localized. Isolation and status-only results remove that workload/data handoff
from the game process and contain a preparation-process failure; these checks
do not establish that every underlying engine/native heap fault is repaired.

Existing prepared-cache, mesh-cache, mesh-preparation and native rendering
settings/profile tests cover the affected lower-level paths. Focused graphical
checks run with the project's non-activating window setting; they are functional
checks, not performance benchmarks.
