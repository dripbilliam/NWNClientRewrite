# Native selected-character stage — partial integration

The offline picker now displays actual installed BICs through the same native
creature planning, model, palette, texture and rig pipeline as the world.
`native_data/bic_visual.gd` extracts typed appearance, body parts, material colors
and equipped records. Physical GFF struct IDs determine equipment slots. Extended
WORD fields and16-byte labels are retained. Active baseitems determines model
types; saved scripts, effects, inventory ownership and world IDs are excluded.

`native_character_preview.gd` attaches optional visual source data to its existing
secure selected-byte decode. A missing appearance does not invalidate otherwise
available stats or grant gameplay state. Server-vault selected bytes use this
same decoder; no direct access to a server's vault is required. Appearance and
equipment completeness is now explicitly tracked. The owned original server's
stats reply omits the equipment field; it is not a full appearance save. See
the [last-seen appearance follow-up](NATIVE-CHARACTER-LAST-SEEN.md) for the
production cache, portrait fallback and successful owned-vault reconnect check.

`native_character_stage.gd` owns one bounded private viewport with original idle
animation, drag rotation and wheel zoom. It uses simple lights without shadows,
disables particles and collisions, and shows the portrait until a complete model
is ready. A source change immediately hides the old viewport image. Only the
latest pending identity can start; old asset workers are observed until complete
before retirement. Decoded graphs use the existing deferred data-disposal owner.
Hidden previews stop rendering and actor updates. None of these states controls
Play admission.

Current final-source receipts: `native-bic-visual-final-v1`588 headless checks
against39 original BICs and102 equipped records; `native-bic-preview-worker-final-v1`
24 secure decoder checks; `native-character-stage-final-v1`12 graphical model,
visibility, camera and retirement checks; `native-picker-real-preview-v2`10
actual offline picker/pointer/model checks. Total634, with no public connections
or debugger exceptions. Earlier headless/graphical iterations remain evidence,
not additional final-source passing counts. Raw comparison input is generated
by `tools/native-bic-visual-fixture.mjs` solely for diagnostics.

The offline screenshot was reviewed: actual original name/classes, body, armor,
weapons and shield render on the stage. It is still a layout prototype: portrait
rows, responsive/narrow layouts, all model families and complete visual design
are unaccepted. The first half-resolution prototype was visibly blurred;
the final stage uses the actual bounded control's pixel resolution.

Production wiring now uses the immediate picker shell and optional model stage.
`native-picker-production-ui-v1` passed 10 graphical controller/pointer/model
checks; `native-picker-production-menu-v2` passed normal native menu startup.
The owned loopback probe `native-server-vault-picker-v1` received 22,155 preview
bytes from the original server with local-vault use disabled. Its actual reply
included appearance (zero equipped records), and the native picker rendered it
and passed 10 checks without reading a local BIC for that reply. Temporary
preview bytes were removed. The separate subsequent server Play probe timed out;
the combined probe is failed, not an end-to-end admission pass. The owned server
process and UDP port were verified absent afterward; its report's serverStopped
flag is false because the probe checks exitCode rather than signal termination.

The subsequent last-seen follow-up supersedes this milestone's initial failed
Play probe: corrected area-ready acknowledgment admits the owned original-server
character, and the final equipped-character test disconnects/reconnects and
verifies its cached gear while still at character selection.

Server resource overrides, advanced item visual overrides, full admission
regression coverage and full UI parity remain unfinished. Do not infer those
from the successful preview checks. Normal client run
`native-ui-manual-1793311561638` was opened at manual server selection for user
testing; no automated public-server connection was made.
