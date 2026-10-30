# Native local content and emitter resource data

The normal native session catalog now discovers enabled Workshop content,
profile/install overrides and portrait directories itself. The protocol host
supplies the selected root and disabled-item settings, not a JS-built mod
inventory or prepared assets. Existing saved settings are preserved. New
native Options controls for changing those settings are still pending.

`workshop_index.gd` and `steam_vdf.gd` retain Steam's installed-item membership
and order, exclude pending items, respect per-mod exclusions and support the
selected root's local content folders. Enabled Workshop HAKs remain global,
below server HAKs and above module archives. `loose_index.gd` inventories
filenames without eagerly reading payloads; forks use independent file reads.
Portrait directories admit only TGA/DDS and cannot supply rules tables.
Selected-source read failure never silently substitutes a different archive.

Two precedence errors in the previous native cutover are corrected: NWSync
uses texture storage class 5, and module archives use 23M rather than 100M.
Portrait/loose texture class 2 precedes NWSync class 5 when selecting formats;
HAK/module class 3 and KEY class 1 follow. Resource lookup and texture-format
selection remain distinct. Server HAK registration retains user/install bases
31M/30M. These policies are checked against the established resolver and its
binary-derived ordering; this change does not establish new native-binary
research claims.

## Native emitter data

`emitter_data.gd` decodes the original 216-byte emitter extension and relocated
scalar/vector controller fields. `binary_model.gd` and `ascii_model.gd` retain
typed emitter settings. `actor_model.gd` retains original linear/Bezier emitter
curves separately from transform tracks, including physical part ownership,
events and supermodel inheritance. FPS does not become mesh opacity or scale.
The renderer does not consume those curves yet.

Native workers prepare original emitter rasters independently of body-part
palette overrides. Both actor and static-world paths retain emitter clips;
non-emitter static models avoid expanding inherited actor animation data.
Model/rig cache identities invalidate the older decoded form, while unrelated
raster/table disk entries remain reusable. Immutable model-template identity
also includes inherited animation dependencies.

The stock `fxpa_cloud02` bitmap is absent from the installed/enabled catalogs.
This was independently recorded in
`backups/animations/creation-experience-emitter-resource-gaps-v1.json` before
this port. Several ordinary placeables name it. An unavailable emitter bitmap
is now an explicit missing dependency/warning rather than rejection of the
model's existing geometry. No nearby texture is substituted. Present corrupt
rasters still report preparation errors. This policy is not proof of the
original binary's texture fallback, nor particle-rendering parity.

The first live content check completed native movement/render-resource work,
but its finish message raced process exit. The native entry now waits for an
explicit protocol acknowledgment before closing. The repeated check observes
that acknowledgment, drained workers, unchanged sources and clean exit.

## Evidence

- `native-local-content-v1.json`: **224 checks** against authored fixtures and
  the offline existing resolver. Covers Workshop ordering/exclusions, pending
  item rejection, global HAKs, rules/portrait isolation, overrides, format and
  source precedence, lazy payloads, worker forks and failed selected reads.
- `native-session-local-content-v2.json` and its native report: actual owned
  Prelude check with **19 enabled mod roots / 66 Workshop HAKs**, 20 entities,
  server-confirmed 1.5-metre movement, native finish acknowledgment, drained
  workers and clean exit. Indexing this actual profile took about seven seconds
  on a native worker. This is not a clean load-time/FPS benchmark.
- `native-emitter-data-v5.json`: **601 checks** of authored binary/ASCII
  emitter fields, all retained channels, original Bezier keys/events, actor and
  static worker routes, texture pixels, missing/corrupt resource behavior and
  cache dependency separation. Includes the stored original reader/dispatcher
  observations for NWN:EE 89.8193.37-17, binary SHA256
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
  This reuses those observations; it is not a new execution of the binary.
  See [the original emitter research](../evidence/particle-emitter-runtime.md).
- `native-emitter-installed-v2.json`: **45 checks** on original installed
  torches and `plc_portal2`, through both actor and static preparation. Original
  model identities, physical counts, smoke/flame/portal textures and emitter
  channels prepare on native workers. No asset payloads are exported.
- `native-actor-emitter-regression-v1.json`: existing captured original actor
  transform/skin/animation regression passes **266,819 checks**. This checks
  the named corpus and recorded hashes, not all possible original models.
- `native-session-local-content-v3.json` is retained as a failed run: mandatory
  emitter bitmap handling rejected furniture naming absent `fxpa_cloud02`.
  The missing-dependency policy and explicit warning fix follow that evidence.
- `native-session-local-content-v4.json`: final normal-heap CDB local rendering
  and movement check after emitter resource integration. All 20 entities and
  9 tiles load (277 meshes / 42 textures); screenshot inspected. Four exception
  traps arm, with no trapped exception or engine/lifetime error. Finish
  acknowledgment, zero remaining workers and unchanged sources pass. Missing
  stock emitter bitmap warnings remain explicit. This is a functional rendering
  check, not particle parity or a clean FPS benchmark.
- `native-session-local-content-v5.json`: later headless check compares raw
  server-replicated distance (1.50003333 m) separately from native presentation
  distance (1.50003326 m). World admission, source identity, acknowledgment,
  drained workers and clean exit pass. The graphical v4 result precedes this
  protocol-measurement-only change and does not pin the final host source.

All checks use authored files, local captures, installed resources or the
owned localhost server. No Arelith connection is made. The older graphical
cutover and its source pins are historical after these source changes.

## Follow-up and remaining work

[Direct native particle runtime](NATIVE-PARTICLE-RUNTIME.md) adds simulation,
standard quad drawing and channel playback after these resource-data checks.
The remaining-work paragraph below records this earlier data-only milestone;
the follow-up lists current evidence and still-missing owners.

Native particle simulation, quad/chunk/lightning drawing, emitter parameter
playback, effects/projectiles/weather and complete visual ownership are still
pending. Prepared emitter data is not a rendered particle system. The old
JS simulation is not invoked by the normal native entry. Advanced UI/NUI,
custom TLK integration, native wire-name/virtual-archive discovery, public
handoffs and the full moving capture/frame-pacing acceptance remain open.
No full migration, native visual parity, sustained 60 FPS or resolution of
historical native faults is claimed.
