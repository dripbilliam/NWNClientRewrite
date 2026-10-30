# Direct native multiplayer entry

The normal `join-arelith.ps1` and no-argument `join-local.ps1` now use
`join-native.ps1`. The server browser and character selector feed the direct
Godot world entry. There is no hidden browser, Three scene, whole-area GLB
export/import, base64 asset transfer or JS-prepared model/texture/animation
data on this route. Godot reads original resources and constructs terrain,
objects and animated creatures through its existing native worker pipeline.

The old compatibility renderer remains available through
`join-arelith.ps1 -StagedRenderer`. Explicit diagnostic fixture switches on
`join-local.ps1` retain that older harness. These are fallback/development
entries, not proof that the native migration is complete.

The Node process retains the existing server protocol and download/cache
service. A separate Electron main process unlocks the existing protected key
and hands it to that process over private stdin; it creates no BrowserWindow.
Neither process prepares render resources. Current saved credentials are
preserved; no test key replaces them unless explicitly supplied to the launcher.
An optional `-Server` prefills the browser; it does not connect automatically.

Native session catalog indexing runs on a worker. It mounts original KEY/BIF,
file-backed module/HAK archives and selected NWSync manifests. NWSync reads
the replacement file cache and the original SQLite cache through the existing
read-only C helper. Godot decompresses raw/zlib/Zstandard content and verifies
decoded sizes and SHA1 before native model/texture preparation. Catalog forks
share immutable indexes and serialized helper requests. The server-selected
manifest order determines NWSync precedence. No server resource name becomes
a filesystem path.

The original installed catalog contains a type-zero entry. Previously the C
helper rejected that entire 203,949-entry catalog. The native path retains
the entry instead, with an authored file-cache/SQLite regression.

Raw server-state snapshots use bounded frames and one acknowledged snapshot
in flight. This prevents a large room from exceeding the native JSON frame
limit or building an unbounded queue. Movement updates remain separate. The
raw objects contain protocol state, not rendered/prepared assets.

## Evidence and limits

- `native-nwsync-v4.json`: 37 authored checks cover manifest aliases, trailing
  ResRef spaces, type zero, corrupt hashes/counts, all three compression forms,
  file and SQLite catalogs, eight concurrent native readers, worker table
  decoding and explicit/destructor helper retirement. No network or GPU work.
- `native-nwsync-installed-v3.json`: 14 checks against already-installed
  original server resources. A 203,949-entry catalog mounts on a worker;
  custom appearance data, an invisible creature, a body part and a creature
  with four original textures prepare natively. This does not render an area.
  Observed mount time was 4.48 seconds; the 7.55 MB appearance table took
  5.40 seconds to prepare. These phases still need caching/optimization.
- `native-data-v10.json`: 80 existing native archive/data/worker checks pass.
- `native-session-menu-v6.json`: headless native browser startup and address
  prefill, zero game-server connections, unchanged source hashes, clean exit.
- `native-session-prelude-v3.json`: normal-heap CDB functional rendering check,
  20/20 entities, 9/9 tiles, 279 meshes, 40 textures and server-confirmed
  1.5-metre movement. Original resources are selected/prepared by Godot.
  Four exception traps armed; no trapped exception or engine/lifetime error;
  screenshot inspected and source hashes unchanged during the run. This is
  a small campaign area, not a dense-room FPS benchmark or binary parity.
- `native-session-prelude-v4.json`: later headless localhost regression after
  protected-login prefill and existing character-vault integration. Native
  browser/world admission and movement pass; this does not verify GPU pixels
  or character export/save commands.
- `native-session-prelude-v6.json`: final headless localhost regression with
  the endpoint shown correctly in the HUD. The graphical v3 result precedes
  this label and later host wiring change; it does not pin the final sources.
  V5 exposed an unset endpoint in the added HUD label and timed out before
  area setup. V6 fixes the endpoint owner and makes preparation exceptions
  terminate with an explicit recorded failure instead of retrying silently.

Follow-up [native local content and emitter data](NATIVE-LOCAL-CONTENT-EMITTER-DATA.md)
adds native Workshop/portrait/override discovery, fixes archive/texture
precedence, and retains emitter fields/channels/rasters. Particle drawing and
the broader migration remain incomplete. Earlier source pins below are historical.

The later [native particle runtime](NATIVE-PARTICLE-RUNTIME.md) connects native
simulation and standard drawing for supported emitters, with original-data,
GPU and normal-entry local checks. Full effects and performance remain open.

No Arelith connection was made for these checks. The new direct route has
not yet been validated in the user's large Arelith room. Custom TLK integration,
native emitter simulation/drawing, effects/weather,
advanced gameplay/NUI menus, casting/combat and server-to-server handoffs
remain incomplete. The direct host currently reports handoffs as unavailable.
No full migration, multiplayer readiness, sustained 60 FPS, visual parity or
resolution of historical native faults is claimed. Older verifier source
pins are historical after this change. Keep the previous accepted rollback.
