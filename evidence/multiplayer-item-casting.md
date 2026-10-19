# Native multiplayer item casting — 2026-10-18

Full multiplayer objective remains active. Item powers now use their own
native request and original-compared shared targeting/menu owners, without
local script, action, spell, charge or effect resolution.

Read-only nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Owned vanilla nwserver SHA256:
98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
No original binary, client session or server settings were patched. Existing
REA session91238 was reused for static research.

## Original wire and gameplay boundary

Sender7c0610, called by805740 and8813d0, writes native6/9: client item ID,
physical active-property BYTE, optional variant BYTE, optional client target
ID and optional three FLOAT coordinates. Variant255 is omitted; the original
server decodes omission as0. Coordinates are present exactly when any FLOAT
component differs from zero. Unlike ordinary spell input, item input applies
neither an epsilon nor a+.3 Z adjustment.

Complete server dispatcher4531b0 reads these fields, checks controlled actor,
blocked input and actor area, calls action-manager bookkeeping37cbc0, then
CNWSCreature::UseItem3a9f70 at453766. The call carries server item/target IDs,
property/variant BYTEs, unmodified vector, actor area and flag1. UseItem checks
ownership/CanUseItem and the active property. Property15 reaches item spell
actions;55/70/80 reach the native skill/trap owners. The replacement sends the
request and applies server results; it does not run those gameplay routines.

inspect-native-network-item-use.py executes the complete original sender and
decoder in isolated synthetic memory. Message readers/writers execute from
the PE; transport, actor lookup, action-manager bookkeeping and final UseItem
are captured boundaries.435 cases cover both message formats, canonical ID
bit patterns, property/variant limits, zero/negative-zero/tiny/nonzero vectors
and actor/blocked/area gates. Supported-format packets agree through used bits;
server routing arguments agree. Initial attempts stopped at uncaptured action
bookkeeping/final UseItem; finalv4 fixes actor-area setup and passes all cases.

## Client path

network_item_input.js owns serialization. Session/frontend/preload/IPC expose
one typed item-use request, scoped to current session/area/control and known
inventory or shortcut items/targets. They never spend item resources locally.

NetworkSpellTargeting reuses prepareItemTarget/itemCreatureTargetVeto/
confirmItemTarget. This preserves separate item auto-self rules, physical
property indices, child variants, target families, creature veto and inventory
target possessor coordinates. Item data comes from replicated properties and
active baseitems/iprp_spells/spells tables. No production potion/module/spell
name checks were added. Target previews remain explicitly diagnosed.

Inventory wheels reuse original-compared itemUseEntries/itemPropertyPage/
itemVariantEntries, including the native slot gaps, More ordinal, variants,
use counts, skill items and Learn Scroll placeholder. Explicit powers drag
through a session-token MIME payload to native30/2 quickbar assignment.
Clicks/F-keys use the same item targeter. Double-click/default Use uses the
native quickbar-selection owner; equipment toggles keep their native request.
Old area/actor/menu/drag contexts are rejected. Scroll learning and container
opening remain diagnosed omissions.

## Validation and limits

76 focused network/casting/IPC/inventory tests and28 singleplayer item/radial/quickbar
regression checks pass. Production buildv4 passes with the existing bundle-size
warning. Isolated Electron fixturev3 passes actual DOM radial click, variant/
More pages, power drag/drop, hotbar click, stale drag rejection and unchanged
canonical inventory/charges. It uses synthetic replicated state/rules and
does not establish resource artwork or live gameplay acceptance. Fixturev1
timed out on a missing Three-addon import;v2 identifies it;v3 adds the local
import-map prefix and passes with empty stderr.

User authorized reconnect/testing while leaving the original client and
server running. Real server runv78 uses the unchanged installed wizard/Prelude,
actual inventory wheel slot3, inventory-to-F1 drag, F1 click and keyboard F1.
Three native6/9 requests, authoritative stack3→2→1,15 rendered drink samples
(native animation70/clip drink), and final server shortcut clear are recorded.
224 samples,77 diagnostics, zero runtime errors or sample failure. Inventory
was closed before the last use, so its cached item remains until a refresh;
v78 does not prove final inventory removal. Follow-upv79 verifies direct power
drag and double-click/default activation, but FAILS final inventory refresh:
the consumed cached row remains after reopen, despite zero runtime errors.

Static native follow-up establishes8562e0 writes the selected panel, clears
repository grid882700, then looks up transport and sends7be060. Server
SetOpen4be9a0 clears its last-update slots/repository/container on close; a
reopen resends current A records, without a D record for the old consumed item.
Native882700 clears GUI cell IDs/icons, not canonical game objects. The port
now clears the repository GUI collection before the page request in both
frontend and session world; cached canonical item objects/metadata survive.
It does not invent item destruction or infer consumption from a spell name.
inspect-native-inventory-panel-reset.py executes the full original panel
owner/sender in40 cases, with grid bookkeeping and app lookup boundaries.
Tests also prove clearing happens before transport can deliver the new page.

Final unchanged-server runv80 PASS:260 samples, three native item-use requests,
direct power-wheel drag to F1, inventory double-click, hotbar click and F1 key,
authoritative3→2→1 stack progression,17 displayed animation70/drink samples,
server shortcut clear and four remaining backpack rows after reopen. Captured
outgoing panel times interleaved with incoming wire replay reproduce the
correct GUI state while retaining the canonical cached object. A regression
test checks all three uses produce a displayed drink clip within6 seconds.
No sample failure or runtime errors. Reopened/final screenshots inspected;
the consumed item and stale waiting label are absent. v79 remains retained
as failed-refresh evidence. These characters start at full HP, so this proves
consumption/presentation rather than healing from injury or hostile effects.

Inspected inventory/hotbar screenshotsv78 show stack2 then1. The inventory
retained a stale “Waiting for inventory” label despite rows being present;
sync now clears that label when rows arrive. The post-quit GPU teardown warning
in v78 stderr is retained separately from the zero in-app runtime errors.

Interactive updated v81 PID43328 is open on the existing server20964. No
automated inputs are configured. Frozen readiness snapshot confirms rendered
player and attached camera. Leave it open for the user; changing live/control
JSON and open stdout/stderr are excluded from checkpoints. Server and original
client were left running throughout the authorized replacement reconnects.

Diagnostic gaps remain visible: item icons, some native effects/object
animations, scene audio, torch/robe, particles/flames and resource fallbacks.
Wand/scroll/variant/daily/skill-item real-server acceptance, complete effects/
audio and concurrent original-client combat/casting acceptance remain open.
Passing this potion cycle does not complete multiplayer or all spellcasting.

Sealed checkpoint backups/multiplayer-native-item-casting-20261018-v1.zip:13847 files/316719989 bytes. Writer64514 finished exit0; every entry length/SHA256 verified and terminal handle consumed. Scope audit13848 entries including manifest,24 selected required entries present,zero forbidden entries. Credential audit inherits13609 unchanged text entries from the fully audited prior checkpoint and scans81 changed/new entries:zero candidates/zero new credentials. Audit and this post-seal note are outside the archive. Interactive43328/server20964 remain open; full goal remains ACTIVE.
