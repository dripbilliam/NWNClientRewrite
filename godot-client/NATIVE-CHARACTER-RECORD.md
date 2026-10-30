# Native character record: controlled-player core

Historical bridge-phase evidence below. The current native desktop refresh path
is `systems/native_game_desktop.gd` with `native_data/game_ui_rules.gd`; the
character record projection no longer depends on the old service described here.
Its original in-game frame/pages are now implemented in a scoped milestone;
full record appearance/content/actions are not accepted. See
[native character frame](NATIVE-CHARACTER-FRAME.md) for current evidence and gaps.

Status: **partial; owned-local display/subscription/assignment core verified**.
The C key and native Character button open a separate movable Character Record.
Character, Skills and Feats tabs use the existing multiplayer record model and
real `hudPanel` requests, pages 0/1/2 and signed -1 on close. Only the current
controlled character is subscribed; this does not infer undisclosed NPC stats.

## Native presentation and data ownership

`tools/character-sheet-service.mjs` reuses the unchanged
`src/character_record_model.js::networkCharacterRecord`. It projects received
identity, classes/alignment, effective abilities/adjustments, HP including
temporary HP, AC, XP/next XP, saves, combat information, skills and owned feats.
The existing active rules supply display modifiers/labels/weapon metadata;
there are no local attack rolls, authoritative stat changes or spell effects.
Unreceived values remain unavailable. Save order remains Fortitude/Reflex/Will
from native fields 98/9a/99. Received damage-group colors become explicit hex
spans; descriptions use the existing rich-text parser and literal native labels
with BBCode disabled. Installed label colons/whitespace are normalized once.

`systems/server_character_sheet.gd` owns the native layout, portrait, six ability
glyphs, combat-detail scroll, skill/feat list and description scroll. Original
portraits and row icons come through the existing resource owners. Isolated
staging v26 adds optional large portrait selection while preserving size 3 for
existing callers. The working JS main/dist and original resources are unchanged.
Native panel position persists independently; selection/scroll are retained per
page and reset for a replacement identity. Reopening keeps the selected tab.

Skill/feat drags carry a private view/entry handle. The native quickbar checks
that the record/entry is live, then the service rechecks world/area/connection,
canonical controlled actor and current skill/feat ownership. Only that backend
entry supplies the actual binding. Rank-zero/nonpositive skill entries are not
draggable, matching the reused model. The original shortcut sender owns the
client layout and sends it to the server; no native UI request supplies trusted
arbitrary feat/skill parameters. Selected skill values are the server's modified
display totals, not locally recomputed training ranks.

Metadata does not await portraits/icons. Each view uses at most four icon workers. Image jobs carry their view/actor/world
owner and cannot decorate retired views.
World reset/close retires native controls and ownership; host shutdown awaits
image tasks. Visible-page signatures avoid rebuilding for movement alone.
Skills/Feats pages also ignore unrelated HP/equipment changes so valid drags are
not cancelled during those updates. Ownership, active token/TLK and visible
list changes still retire the appropriate view. The Character page continues
to follow actual stats, equipment and portrait changes.

## Actual local evidence

`reports/native-character-sheet-local-v3.json` passes **16 prerequisite gameplay
checks plus 26 native record checks**, with canonical-value comparison true,
native exit 0, no rejected sheet requests, no renderer errors and zero pending
image tasks. Its engine log is retained separately. This is real owned-local
server admission/presentation and protocol traffic, not a socket-only demo.

The native record is independently compared with the same-view raw canonical
actor data captured by the host: abilities **10,16,12,19,10,12**, AC **17**, HP
**77/77**, XP **105000**, saves **6/8/9**. Actual inventory-stat records include
abilities, adjustment arrays, combat/saves, XP, feats and the Skills page record.
An authored server script applies a five-second +4 Strength effect: native
display observes **10 → 14 → 10**, positive adjustment coloring and actual expiry.
The client never changes that score or expires the effect locally.

Actual skill and feat selections display installed descriptions and original
icons. Native drop callbacks assign skill **20** to slot **34**, and feat **944**
to slot **35**. A real server character export subsequently contains both exact
QBList bindings. The raw export is inspected inside its legitimate save callback
before the existing SDK zeroizes it; the export SHA256 equals the external
temporary vault's saved BIC hash. No original BIC or user vault is overwritten.
The installed wizard BIC was independently hashed against its admitted bytes
and remains unchanged. This proves server receipt/persistence of assignments,
not execution of every assigned action.

Screenshots `native-character-sheet-local-v3-sheet.png`, `-sheet-skills.png`
and `-sheet-feats.png` capture native presentation. The earlier equivalent v1
frames and final v2 Character frame were visually reviewed; v2 corrected a
duplicate-colon formatting issue. The live check additionally proves close and
reopen, stale drag retirement and actual WASD displacement with character,
inventory and spellbook windows all open. It uses native callbacks/key-state
input; physical mouse dragging/camera gestures are not exhaustively established.

`reports/native-character-sheet-node-v3.log` passes **59 Node cases** across the
record adapter/model and existing inventory/store/spellbook/protocol owners.
Coverage includes original model semantics, missing data, RGB/literal text,
private handles, hidden/lost skills, removed feats, replaced actors/worlds,
asynchronous retirement, delayed images, relevant-page refresh and command
bounds. `reports/character-sheet-ui-native-v4.json` passes **18 authored native
checks**; `reports/character-sheet-book-ui-regression-v1.json` passes **22 existing
native spellbook/quickbar checks**. Their engine logs are clean.

The v26 real merchant regression also passes **16 gameplay +25 store checks**:
`reports/native-character-store-regression-v1.json`, no rejected requests or
renderer errors, zero pending inventory/record image work. The final additional
record-only visible-signature refinement is covered by the final v3 record run
and Node cases; it is not used by the merchant test's closed record window.

`tools/create-record-server.mjs` extends the verified authored GodotStores module
using installed script API signatures/constants. Fixture metadata is
`reports/character-record-server-fixture-v1.json`; GodotRecords SHA256:
`68805a818abcff3ae33318f66bbe6764aa1451dc2c771e38756544a6f2793d8b`.
Run the owned GodotRecords server and
`join-local.ps1 -CharacterSmoke -Report <unused-name>.json` to repeat.
All proprietary models/textures/template payloads stay in the installation or
external temporary runtime bundles; fixture code/data is authored metadata.

Weak/failed earlier evidence remains: native UI v2 reported successful process
exit despite a probe inheritance-signature compile error; the error was read
and fixed, and v3/v4 native logs are clean. Live v1 passed all 26 native checks
and canonical comparison but its export verifier watched the ordinary message
event, which intentionally does not expose raw export bytes. It was rejected.
Live v2/v3 inspect the owned save callback and prove the exported bindings/hash.

## Remaining scope

This is not full character/player-window or shortcut-action parity. Associate/DM
record access, broader custom-content/display cases, physical gesture coverage,
pending record/image work across actual transitions/reconnect, exact original
record skin/bitmap fonts and all combat-detail branches remain open. In
particular, skill shortcut activation still reaches the existing session's
unimplemented type-3 activation branch; this milestone proves assignment/save,
not every skill action. Native level-up, map/journal/party, remaining quickbar
actions, full NUI, settings/audio and the rest of the migration ledger remain.

Only the owned local server was contacted. The unrelated Godot editor was
preserved. Fixture FPS is not sustained complete moving captured-world or
>=60 FPS acceptance. The full migration goal stays active and incomplete.
