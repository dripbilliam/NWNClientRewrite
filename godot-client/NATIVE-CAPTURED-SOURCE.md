# Native cached-source recovery and live missing materials

The captured room now obtains its formerly unrecorded ground-item DDS from the
existing local NWSync cache. `capture_source.gd` permits only explicitly pinned
raw resources, after binding the selected cached manifest to the exact captured
model bytes. Captured positive resources and recorded negative lookups retain
priority. Unlisted resources and other recording gaps remain unavailable.
`capture_setup.gd` mounts/verifies the catalog on a native worker; no JavaScript
model, texture or scene preparation is involved. Helpers close after workers.

`reports/native-capture-input-cache-v1.json` is the default offline room input.
Its source supplement pins manifest
`1fb727f690a7e0c462f79ef9177f5977c73d756f`, captured model `it_mscmedp_008`
SHA256 `56b39f8bde338d868227acef667744f7d61bbf0567621ffe49a83ce2fdb57990`,
and DDS `ait_mscmedp_008` SHA1
`34bc7421ee6c2b42810941f7d388c26a288e5a60`.
The DDS was not recorded originally; this establishes its association with the
exact cached model, not recording-time pixel identity. No proprietary payloads
are copied into the workspace.

`native-capture-source-v3` passed 42 checks under CDB, including authored
concurrent reads, invalid-source rejection, exact installed DDS/model preparation
and helper cleanup. `native-capture-cached-source-default-v1` assembled 48 tiles,
889 static objects, eight creatures and the previously missing ground item;
source pins stayed unchanged, exception traps were armed, and workers drained.
Screenshot inspected. These reports precede the subsequent live-catalog change.
The room still has 1,182 diagnosed emitter failures and does not establish full
visual or performance acceptance. Complete moving protocol replay remains open.

## Live area load abort

Session `native-session-1792918230620` exited with code 1 after model
`trm_udoor_10` referenced absent `sam-material` and `dwc_gen_04` referenced absent
`standardmaterial`. These asset errors propagated to the fatal world-load path;
this was not evidence of a native access violation.

For live `resource_catalog.gd`, a missing bitmap in the selected complete catalog
now uses the existing diagnosed missing-texture path: preserve geometry and
authored material colors without inventing a bitmap. Existing corrupt rasters
and unresolved PLTs still fail. Capture catalogs retain their stricter distinction
between a recorded miss and an unrecorded dependency. This does not implement
general per-object recovery from every preparation failure.

`native-live-missing-material-v2` passed 15 checks under CDB with normal heap,
four exception traps and unchanged sources. Authored tests cover retained mesh/
material colors, corrupt rasters, unresolved PLTs and strict capture gaps. Offline
install/Workshop/NWSync preparation retained two meshes for `trm_udoor_10` and
seven for `dwc_gen_04`, with the exact missing names diagnosed. No public server
connection was made. The sandboxed v1 could not mount the external sources and
remains retained as failed evidence.

`native-session-missing-material-v1` passed the actual default launcher against
the owned local server, including movement and clean shutdown. A user-driven
public reconnect is still required to confirm the entire affected live area.
Full migration, effects parity and the 60 FPS target remain unaccepted.
