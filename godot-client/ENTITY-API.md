# Client entity API v1

The read-only provider, native adapter, autoload, session hooks and opt-in
localhost REST v1 service and external browser explorer are implemented.
The session publishes accepted raw snapshots and movement boundaries into
`ClientAPI.entities`, independently of visual admission. The existing running
client was not restarted; live-client/server acceptance is not claimed.
The isolated headless checks exercise the actual provider, bootstrap,
autoload, accessor, existing native motion owner, native session receiver and
authenticated loopback HTTP sockets.
The session test uses authored raw/UI/world owners and area-ready state.

## Consumer access

Normal scene projects register `client_api.gd` as the `ClientAPI` autoload and use
`ClientAPI.entities`. The client's current `--script native_session_world.gd`
launch bypasses Godot's autoload initialization. Its bootstrap calls
`client_api.gd.install(root)`, and feature scripts use the explicit Godot preload
convention below. Both access paths return the same `/root/ClientAPI` provider:

```gdscript
const ClientAPI = preload("res://systems/client_api/access.gd")

func inspect_controlled() -> void:
    var controlled: Dictionary = ClientAPI.entities.get_controlled()
    if not controlled.available:
        print(controlled.reason) # control_not_received or entity_not_known
        return
    var entity: Dictionary = controlled.entity
    print(entity.identity.object_id)
    if entity.replicated.available:
        print(entity.replicated.value.get("hitPoints"))
```

`access.gd.entities` is null before installation. `ClientAPI.entities` is a
get-only provider property. The API does not offer gameplay commands, an add-on
loader, or a security sandbox for arbitrary code running in the same process.
Consumers use the public query methods/signals; underscore methods and the
binding adapter belong to the session owner.

## Queries

| Method | Result |
| --- | --- |
| `get_by_id(object_id, include_presentation = true)` | Detached entity dictionary, or null if unknown/removed/unreadable. |
| `get_reference(object_id)` | Detached scoped reference, or null if unknown. |
| `resolve(reference, include_presentation = true)` | Current detached entity, or null for any stale/foreign reference. |
| `list_references(filters = {})` | ID-sorted lightweight references. No canonical object copies/lookups. |
| `page_references(filters = {}, after_id = -1, limit = 50)` | Bounded ID-sorted reference page (`items`, `has_more`); at most 100 items. |
| `list_entities(filters = {}, include_presentation = true)` | Detached snapshots on explicit request. |
| `get_controlled(include_presentation = true)` | Availability, received control ID, reference, entity and reason. |
| `get_player_character(include_presentation = true)` | Explicit player identity result, separate from control. |
| `get_scope()` | Active flag, connection, area generation, area ID and scope ID. |
| `diagnostics()` | Detached publication/query counters; useful for local tests. |

Filters are `object_type` (numeric), `object_types` (array of numeric codes),
`current_area` (bool), and `area_id` (numeric). Supplied filters combine with AND.
Unknown type/area fields do not match those filters. The unfiltered list includes
off-area client-known entities and objects without a visual model or a pose.
Replication-removed cached objects are excluded. Object IDs are unsigned 32-bit
values except the protocol invalid sentinel `0x7f000000`.

```gdscript
var entities: RefCounted = ClientAPI.entities
for reference in entities.list_references({"object_type": 5, "current_area": true}):
    var entity: Variant = entities.resolve(reference, false)
    if entity != null:
        print(entity.identity.name)

var saved_reference: Dictionary = entities.get_reference(known_object_id)
# Later, including after a transition:
var still_same_entity: Variant = entities.resolve(saved_reference)
```

Received control can name an entity whose raw record has not arrived. Then
`get_controlled()` preserves `object_id`, returns null reference/entity, and
reports `entity_not_known`. It never substitutes another character.

The current raw-world header transports `controlledId`, sourced from
`NetworkWorld.localObjectId`. Both object-control and player-state reception can
change that value. It does **not** establish the player's original character
during possession. Therefore the native adapter supplies no player identity and
`get_player_character()` returns `available: false`, null identity/reference/data,
and `reason: identity_not_received`. A future authoritative provider may supply
`{available: true, object_id: id, provenance: "explicit source"}` at a publication
boundary. Tests cover this identity differing from the controlled entity. A
player-list name match or the controlled ID is insufficient provenance.

## Entity fields and missing data

All query dictionaries/arrays are detached, recursively, on each call. Consumers
may mutate their returned copy without touching another query or canonical state.
There are no live Nodes, Resources, Callables, Signals, or RIDs in a view.
Unsupported values and cyclic/overly deep containers become null with their
paths listed in `unavailable_paths`. Packed arrays become detached ordinary
arrays. Built-in value types such as Vector3 remain values.

| Field | Contract |
| --- | --- |
| `api_version` | `1`. |
| `reference` | Connection/area/lifetime reference described below. |
| `revision` | Last raw boundary that published this entity row. |
| `identity` | Object ID; availability-wrapped object type, area ID, received name and source lifetime; numeric type's `type_name`, or null when missing. |
| `appearance` | `{available, value}` for the raw root appearance field. Further appearance properties can also occur inside `replicated`. |
| `replicated` | `{available, value}` for the last published raw replicated dictionary, without stat normalization. |
| `character` | `{available, value}`; available sections are `stats` (replicated stats), `inventory_stats`, and `player_state`, each wrapped with `{available, value}`. |
| `received` | Last raw client read-model object, with `source: client_received_read_model`, provenance, and boundary revision. Contains other available fields such as `item`, `staticState`, `lightState`, inventory locations and decoded state. Excludes separately classified client caches/lifetime metadata. |
| `client_data.ability_cache` | Availability-wrapped `clientAbilityCache`, with `source: client_initialized_ability_cache`. |
| `client_data.disclosure_lifetime` | Availability-wrapped client-known disclosure token, with `source: client_disclosure_run`. Internal bridge metadata, not a permanent server-object ID. |
| `client_data.skill_admission` | Availability-wrapped `clientSkillAdmission`, with `source: client_received_skill_cache`. Compact native-received cache evidence, not computed ranks or a UI/rules availability result. |
| `presentation` | Availability and an optional fresh motion sample, described below. |
| `unavailable_paths` | Explicit paths for values that cannot safely be represented. |

Field presence controls `available`. An absent field is `{available: false,
value: null}`. A received explicit null remains present with null value. No
missing numeric stat becomes zero; the API computes no ability score, HP, AC,
feat, level, spell availability, or localized name. Names retain their decoded
protocol structure, including string references where present. Unknown numeric
object types get `type_name: unknown` while retaining their raw type.

`received` is a decoded, merged client read model, not a verbatim network packet.
For example `nativeLifetime` is transport metadata. `playerState` includes
maintained received state such as accumulated automap data. The API preserves
source values without claiming per-field wire timestamps.
`mergeNetworkAbilityCache` in `src/network_spell_gain.js` initializes bonus and
Dex cells to zero locally before merging received updates. Its cache is exposed
only under `client_data`, with explicit provenance; those initialized values are
not evidence of a received zero stat. The API does not infer missing-source
availability for individual cells in that existing cache.

## Received state versus presentation

`replicated.value.position` and the corresponding `received` field are from the
latest accepted full/delta raw-world publication. They are not replaced by native
motion simulation. Independent movement messages can precede the next raw-world
publication, so this view does not claim to be the newest individual packet.

When available, `presentation` has `source: client_simulated`, `coordinates: NWN`,
`sample_ticks_usec`, the last published movement `input_revision` (`-1` when no
movement publication has been observed), and `value` containing only fields
present in the native motion owner: `lifetime`, `position`, `render`,
`orientation`, `targetOrientation`, `animation`, `active`, `driveHeld`,
`previewBase`, `path`, and `cursor`. `position` can be predicted/simulated;
`render` can be corrected/interpolated. `lifetime` here belongs to the motion
owner and is **not** the entity reference lifetime. These are NWN axes; the API
does not expose renderer transforms or require an instance. It does not claim to
classify every native sample as purely prediction versus interpolation.

Presentation is sampled only on query. There are no API process callbacks and no
registry copying, scanning, or event publication on native simulation frames.
`include_presentation = false` avoids even the presentation lookup and reports
`reason: not_requested`. Otherwise an absent sample reports
`presentation_not_known`.

## Reference and event semantics

References contain `api_instance`, `scope_id`, `connection`, `area_generation`,
`area_id`, `object_id`, and `lifetime`. Every field must match to resolve. Treat
them as opaque, process-local data; persisting a bare ID does not preserve entity
identity. An API instance has its own monotonically increasing scope and lifetime
counters. Reset/reconnect never resets those counters. A new API instance has a
different `api_instance` even if its counters start again.

Changing connection, area generation, or current-area identity invalidates every
old reference, including references to retained off-area records. Explicit
removal, absence from a full publication, `replicationRemoved`, or a changed
client-known disclosure token retires the entity lifetime. A removed ID returning
with the same transport token still gets a fresh API lifetime.

`NetworkWorld.entityDisclosures` owns a compact weak proxy-to-token map and a
monotonic counter. It observes decoded D records only after successful canonical
application. This marks a client-known disclosure boundary, not permanent game
object destruction. D followed by A in one packet or between raw snapshots gets
a new token even when the canonical proxy is retained. A alone preserves the
token; area import preserves retained proxies, while the API's separate area
scope still invalidates references. World reset clears weak membership without
resetting its counter. No extra whole-world scan or second entity registry is
introduced; tagging occurs within existing raw-row serialization.

The raw bridge field is `clientKnownLifetime`, exposed separately under
`client_data.disclosure_lifetime`. It is explicitly namespaced from renderer
`nativeLifetime` (the unchanged `RawCombatEvents` WeakMap identity). Older/authored
sources without the new field retain the legacy token fallback. An explicitly
present malformed/exhausted disclosure token never falls back: the real session
observer invalidates API scope/references while preserving gameplay application
and ACK behavior. If neither source supplies a usable token, legacy publications
conservatively retire/re-add that ID. The API does not infer identity from an ID
alone. A canonical token mismatch during lookup returns null even before a
replacement boundary is committed.

The [disclosure-lifetime validation](NATIVE-ENTITY-LIFETIME.md) records the actual
World/raw-frame/native-session pipeline and196 source-hashed checks. This
includes coalesced D+A stale-reference outcomes; it is isolated headless
acceptance with authored decoded records/native owners, not live-client or
game-server validation.

Signals on `ClientAPI.entities` are:

- `entity_added(event)` / `entity_updated(event)`: reference, object ID, raw
  boundary revision, and source (`received` or `presentation_input`). Movement
  updates also include `input_revision`.
- `entity_removed(event)`: the retired reference, object ID, revision and reason.
- `controlled_entity_changed(event)`: previous/current ID and optional reference,
  plus revision. A new lifetime for the same controlled ID counts as a change.
- `scope_changed(event)`: previous/current detached scope and revision.

Events deliberately contain compact identity data; consumers query a snapshot
only when needed. Event dictionaries and all nested containers are detached and
read-only so one listener cannot corrupt another listener's payload. Duplicate
or older movement row revisions do not publish another update. Incoming full
rows publish `entity_updated` even when values equal an earlier full snapshot;
the signal denotes publication, not a computed field-by-field diff. `revision`
counts raw boundaries/reset operations; it is not a simulation-frame counter.

Each boundary first commits all metadata, then emits synchronously in this order:
scope change, ID-sorted removals, ID-sorted additions, ID-sorted received updates,
then controlled change. All listeners see the final committed query state. A
removed reference may therefore already coexist with a new lifetime for the same
numeric ID. Retained event payloads do not change after future transitions.
Session-owner publication calls are rejected while these events are dispatching.

```gdscript
func start_observing() -> void:
    ClientAPI.entities.entity_updated.connect(on_entity_updated)

func on_entity_updated(event: Dictionary) -> void:
    var entity: Variant = ClientAPI.entities.resolve(event.reference)
    if entity != null:
        print(event.source, entity.identity.object_id)
```

## Canonical owners and native integration

The current diffs of the shared launch/session files were inspected before each
integration edit. They contain unrelated in-progress protocol, rendering, session
and UI work, all preserved. The two shared files were backed up byte-for-byte to
`.cache/entity-api-checkpoints/20261102-061338/` before the API hooks were applied.

| Data | Existing owner / boundary |
| --- | --- |
| All raw client-known objects | `native_gameplay_ui.gd` `set_world` / `update_world`, retained in `gameplay_ui.text.objects`. It receives all raw rows, independent of renderer admission. |
| Original canonical registry | `src/network_world.js` / GameObjectArray, transported by `native-session-host.cjs` and raw full/delta frames. |
| Client-known disclosure identity | `src/network_entity_lifetimes.js`, owned by `NetworkWorld`; host raw-row serialization adds `clientKnownLifetime`. |
| Renderer transport identity | `tools/raw-combat-events.cjs`, `RawCombatEvents.object()` retains unchanged `nativeLifetime`. |
| Current control | Accepted raw-world header `controlledId`; no independent PC identity supplied. |
| Native motion | `world.motion.objects`, owned by existing `network_motion.gd`. |
| Connection/area lifecycle | `native_session_world.gd`: `session_connection`, `epoch`, `reset_session`, accepted `raw-world-end`. |
| Renderer/selection | `live_world.desired` is type/area/pose filtered; `entity_registry` is selection-only. Neither determines API entity existence. |

Initial bootstrap/session integration changed `project.godot` and
`native_session_world.gd`. The later disclosure-lifetime fix also adds narrow
World accepted-update/reset hooks and host raw-row metadata. The following
describes the installed session hooks.
`native_live_world.gd` was not edited for this API. Source integration was tested
without connecting or restarting the live client.

1. `project.godot` registers the exact normal-scene autoload:

```ini
[autoload]

ClientAPI="*res://systems/client_api/client_api.gd"
```

2. `native_session_world.gd` has this internal binding member and helpers.
   Both callbacks resolve the current owners, rather than retaining a retired
   world/UI node. They are private to the binding and never enter data views:

```gdscript
var entity_api_binding: RefCounted

func entity_api_received(id: int) -> Variant:
    return gameplay_ui.text.objects.get(id) if is_instance_valid(gameplay_ui) else null

func entity_api_presentation(id: int) -> Variant:
    return world.motion.objects.get(id) if is_instance_valid(world) and not world.closed and not world.retiring else null

func entity_api_movement(message: Dictionary) -> void:
    if entity_api_binding == null or closing or message.get("kind") != "movement": return
    if int(message.get("connection", -1)) != session_connection or session_connection == cancelled_connection: return
    if not is_instance_valid(world) or int(message.get("generation", -1)) != epoch or int(message.get("areaId", -1)) != world.area_id: return
    if world.closed or world.retiring: return
    entity_api_binding.presentation_records(session_connection, epoch, world.area_id, message.get("records", []))
```

3. `native_session_world.gd.run()` calls the idempotent `install_entity_api()`
   helper before its existing `super.run()`, installing/binding before protocol
   reception. The application uses `--script`, so explicit installation is
   required even with the autoload entry:

```gdscript
func install_entity_api() -> void:
    if entity_api_binding != null: return
    var api: Node = preload("res://systems/client_api/client_api.gd").install(root)
    if api != null:
        entity_api_binding = api.bind_native(entity_api_received, entity_api_presentation)
```

4. `raw-world-end` captures `received_before = received` before its existing
   `super.receive` call. After the existing `if closing: return`, it calls
   `entity_api_snapshot(snapshot, received_before)` and continues the original
   `accepted_raw_serial` assignment and acknowledgment path unconditionally.
   The API is a non-gating read-only observer: its scope checks never skip core
   application, suppress an acknowledgment, or call `fail()`/disconnect.
   Acceptance checks live entirely inside the API helper:

```gdscript
func entity_api_snapshot(snapshot: Dictionary, received_before: int) -> void:
    if entity_api_binding == null: return
    if received == received_before:
        entity_api_snapshot_diagnostic("base_ignored", false)
        return
    if received != received_before + 1 or not initialized or not is_instance_valid(world) or not is_instance_valid(gameplay_ui):
        entity_api_snapshot_diagnostic("owner_scope_missing", true)
        return
    if epoch != int(snapshot.generation) or gameplay_ui.generation != epoch or world.area_id != int(snapshot.data.get("area", {}).get("id", -1)) or gameplay_ui.area_id != world.area_id:
        entity_api_snapshot_diagnostic("owner_scope_mismatch", true)
        return
    if not entity_api_binding.commit(session_connection, epoch, world.area_id, snapshot.data):
        entity_api_snapshot_diagnostic("binding_rejected", true)
```

   `objects` in a delta must be complete merged raw object rows, as supplied by
   the existing `RawWorldDeltas` producer; the API does not merge field patches
   into another world store. The canonical object owner must finish applying all
   additions/removals before `commit`. An initial/changed area must use a full
   publication. Snapshots ignored by the base receiver never publish API state.
   This does not change the receiver's pre-existing acknowledgment behavior.
   An accepted but inconsistent owner scope or rejected binding invalidates only
   the API scope. `report.entity_api_observer` retains fixed `ignored` and
   `invalidated` counters plus a finite `last_reason`; it retains no payloads or
   history. After invalidation the API requires a consistent full publication
   to become available again; it never requests or forces a gameplay resync.

5. **Both** paths of the existing `receive()` profiling wrapper call
   `entity_api_movement(message)` immediately after `receive_profiled(message)`.
   Keep `accept_connection` in the existing receiver. This observes the existing
   base `movement` handler after application, without modifying the base file or
   adding a frame poll. The adapter ignores unknown IDs and duplicate/stale
   movement row revisions. No movement callback modifies raw received fields.

6. `reset_session()` and `shutdown()` invalidate the API before teardown:

```gdscript
if entity_api_binding != null: entity_api_binding.reset("session_reset")
# Use reset("shutdown") in shutdown().
```

   REST starts only when explicitly enabled, inside `ClientAPI._ready()`.
   `native_session_world.shutdown()` calls the null-safe
   `preload("res://systems/client_api/access.gd").stop_rest()` before its existing
   API reset. This is the only additional shared-file change for REST; the
   pre-REST session source is backed up in
   `.cache/entity-api-rest-checkpoints/20261102-070607/`. Session reset/reconnect
   retains the per-launch endpoint and token while entity scope becomes inactive.
   API node removal also closes the endpoint. Startup/bind/discovery errors only
   disable the endpoint and appear in `ClientAPI.rest_status()`; they do not
   alter core application, acknowledgment, disconnect or failure behavior.

The provider retains only ID, source/local lifetime, raw/movement revision,
type and area metadata. Deltas touch changed rows and explicit removals; movement
publications touch their records. Full reconciliation/transition can visit all
known IDs. Deterministic event ordering adds ID sorting at publication boundaries.
No boundary copies entity payloads. Explicit snapshot queries copy only requested
entities. Full snapshot enumeration occurs only when a consumer asks for it.

## Localhost REST v1

The service is off by default. It binds **only `127.0.0.1`**, never a wildcard or
LAN address. It offers authenticated HTTP/1.1 `GET` queries over the same native
provider, including previsual entities. There is no command, filesystem, console,
chat, gameplay-action or credential endpoint, and no add-on loader or event stream.
The currently running client was not restarted or modified in memory. Enable the
service for your next manual launch to use it in that client process.

### Launch and discovery

For the existing PowerShell launcher, set these variables in the launching
PowerShell session. The launcher inherits them; no new launcher switch is needed:

```powershell
$restDiscovery = Join-Path $env:LOCALAPPDATA 'NWNClient\EntityAPI\discovery.json'
$env:NWN_ENTITY_API_REST = 'true'
$env:NWN_ENTITY_API_REST_PORT = '8765'
$env:NWN_ENTITY_API_REST_DISCOVERY = $restDiscovery
& .\godot-client\join-native.ps1 # Keep your usual launch options if you use any.
```

The equivalent Godot user arguments (after Godot's `--`) are:

```text
--entity-api-rest=true
--entity-api-rest-port=8765
--entity-api-rest-discovery=C:/Users/you/AppData/Local/NWNClient/EntityAPI/discovery.json
```

Explicit arguments override the corresponding environment variable.
`--entity-api-rest=false` disables inherited opt-in. Port `0` requests an available
ephemeral port; clients must then use the discovered URL. Ports are canonical
decimal integers in `0..65535`; malformed/duplicate REST arguments disable REST
without failing the game. The current launcher does not forward arbitrary Godot
arguments, so its normal supported opt-in is the environment example above.
No bearer token is accepted in arguments or environment variables.

With no discovery option, the path is
`user://entity-api-rest-<client PID>.json`, under Godot's user data directory. On
Windows for this project that normally means
`%APPDATA%\Godot\app_userdata\NWN Native Engine Prototype\`. The explicit example
uses a known path under the user's local application data instead. Parent
directories are created. An existing discovery file is never overwritten;
another live client or a stale crash file can cause `discovery_exists`. Select a
different file for another instance. Normal shutdown removes only a file that
still matches this service's kind, PID and token; a replaced file is preserved.

Discovery JSON contains `kind: nwn-client-entity-api-rest`, `api_version: 1`,
`pid`, `base_url` (for example `http://127.0.0.1:8765/api/v1`), `started_utc`, and
`bearer_token`. Godot generates 32 cryptographically random bytes for each service
launch. Read the file locally without printing the token, then send
`Authorization: Bearer <bearer_token>`. Tokens are not logged, returned by HTTP,
or included in status/receipts. They rotate when the service starts again and
remain the same across normal game-session resets/reconnects. Stop removes its
credential file and closes accepted sockets; a crash can leave a stale file
whose token no longer has a listener.

### Routes and responses

All successful responses contain `api_version: 1`. All routes require the
bearer header. Bodies are detached JSON data; modifying a response cannot change
the client. Presentation is **off by default** for HTTP point/control queries;
use `presentation=true` to request an on-demand native motion sample.

| GET path relative to `base_url` | Parameters | Response |
| --- | --- | --- |
| empty path | None | Service name, read-only flag and available route names. |
| `/scope` | None | `{scope: ...}`; inactive scope is a normal `200`. |
| `/entities` | `object_type`, `area_id`, `current_area`, `limit`, `cursor` | `{scope, items: [{object_id, reference}], page: {limit, returned, has_more, next_cursor}}`. References only; no entity payload copies. |
| `/entities/{decimal ID}` | `presentation` | `{reference: opaque token, entity: native view}`; unknown/removed ID is `404`. |
| `/references/{opaque token}` | `presentation` | Same point view, but only for that exact connection/area/entity lifetime; stale or foreign reference is `410`. |
| `/controlled` | `presentation` | `{result: {available, object_id, reference, reference_token, entity, reason}}`; unknown control/entity is an available `200` status result. |
| `/player-character` | `presentation` | Same identity result with provenance when explicitly known; current native protocol normally reports `identity_not_received`. |

Native field/availability/provenance semantics above apply unchanged. `received`
means the **last accepted full/delta client read model**. Faster movement inputs
may change presentation before another received snapshot. `client_data` remains
separate from received server fields; initialized ability-cache values are not
reclassified as received zero stats.

IDs and filters use canonical unsigned decimal strings (no sign, leading zeroes,
hex, fractions or protocol-invalid sentinel). `object_type` accepts `0..255`;
`area_id` uses valid object IDs. Booleans accept only `true` or `false`. Limit is
`1..100`, default `50`. Type and area filters combine with AND. Unknown, repeated,
empty or malformed parameters return `400`. This narrow URI grammar has no
percent/plus decoding; its numeric, boolean and opaque-token values need no
escaping. Trailing slashes and undeclared routes are not aliases.

Treat `reference`/`reference_token` and `page.next_cursor` strings as opaque. They
carry exact decimal identity values without JavaScript integer rounding. Use the
external reference token for later resolution rather than reconstructing one
from the JSON entity's native reference dictionary. A cursor belongs to the API
instance, area scope and filter set; stale scope gives `410`, changed filters or
malformed cursors give `400`. Keep the same filters on the next page. A page does
not freeze world state across requests: additions/removals can happen between
pages. Restart enumeration to reconcile concurrent changes. The server scans
compact identity metadata on request and retains at most `limit + 1` candidate
IDs; it never copies the entire entity payload registry for pagination.

Error bodies are `{api_version: 1, error: {code: "..."}}` and never echo headers,
tokens, request contents or credentials. Statuses include `400` invalid input,
`401` missing/wrong token, `403` rejected Host/browser context, `404` unknown
entity/route, `405` non-GET method, `408` incomplete request timeout, `410` stale
reference/cursor, `414` long target, `417` unsupported expectation, `422`
representation limit, `429` rate limit, `431` oversized headers, and `505`
unsupported HTTP version. `405` includes `Allow: GET`; `429` includes
`Retry-After: 1`. Re-read discovery after a client/service restart.

### JSON values and bounds

JSON null remains null. Missing fields retain `{available: false, value: null}`;
explicit received null retains `available: true`. Unsupported native objects
remain null with the native `unavailable_paths`; no Node/Resource handle escapes.
Additional unsupported JSON representations list
`representation_unavailable_paths` instead of inventing values.

Godot value types use `{"$type": "Vector3", "value": [x, y, z]}` and analogous
tags for Vector2/4 and integer vectors, Color, Quaternion, Rect2/2i, AABB, Basis,
Transform2D/3D, Plane and Projection. Components retain their original order and
coordinate values; presentation vectors are still **NWN coordinates**. Integers
outside the exact JSON/JavaScript range `±9007199254740991` use
`{"$type":"int64","value":"exact decimal"}`. NaN/infinities use a `float` tag
with `NaN`, `Infinity` or `-Infinity`. Dictionaries with non-string keys or a
received `$type` key use `{"$type":"Dictionary","entries":[[key,value],...]}`
to avoid key/type collisions. These tags preserve data rather than coercing it
to zero, strings without type, or renderer coordinates.

Authenticated route attempts share a conservative **10 requests/second** bucket
with burst `4`; excess requests receive `429`. Each frame accepts at most two
connections, services at most eight clients and two route attempts, reads at most
16 KiB (1 KiB per client step), and writes at most 32 KiB (4 KiB per client step).
Headers are capped at 8 KiB/32 fields, targets at 2048 characters, and responses at
512 KiB. An incomplete request or blocked writer has a three-second deadline.
Connections close after one response; keep-alive, request bodies, transfer
encoding, pipelining and HTTP upgrades are unsupported.

Before copying an entity for HTTP, the native read path caps source visits and
dictionary entries at 8192, source text at 65536 characters, depth at 48, keys at
256 characters and diagnostic paths at 2048. JSON conversion is separately capped
at 16384 visits, 131072 text characters and depth 48. A limit returns `422` with
**no partial entity or silently truncated stats**. Native queries with their
default arguments retain their existing full-view behavior. The HTTP limits are
passed through an internal caller-owned copy budget; they do not change source
owners or the authoritative registry.

Socket operations are partial/nonblocking. The polling loop has a cooperative
1.5 ms work budget: it can defer the next client, but cannot preempt one provider
metadata scan, bounded entity copy or JSON encode. It is not a hard latency bound.
There is no entity scan/copy on idle HTTP frames; all views are built only for
authenticated requests. This service adds no gameplay commands or core-flow
failure path when it is busy, cannot bind, or cannot write discovery.

Browser API access is restricted to authenticated fetches from the exact local
explorer origin. Host must be `127.0.0.1:<port>` or `localhost:<port>`; an Origin
header, when present, must exactly match `http://` plus that Host. Foreign/null
origins, unexpected hosts, cross-site/same-site contexts and direct browser
navigation to API JSON are rejected. Browser fetches use `Sec-Fetch-Site:
same-origin`, `Sec-Fetch-Mode: same-origin` or `cors`, and the literal
`Sec-Fetch-Dest: empty`. Native tools without browser metadata remain compatible.
Every API route still requires bearer authorization. There is no CORS allowance.
Accepted peers must be IPv4 loopback. Responses use `no-store`, `nosniff`,
`no-referrer` and a restrictive content policy.

### Browser explorer

After the next REST-enabled client launch, paste this address into the browser's
address bar (replace the port if configured differently):

```text
http://127.0.0.1:8765/explorer/
```

Choose **Choose discovery JSON**, or drop the same per-launch discovery file
onto the connection panel. For the explicit launch example above, that file is
`%LOCALAPPDATA%\NWNClient\EntityAPI\discovery.json`. It is read locally by the page;
the file is not uploaded. Only the bearer authorization header is sent to the
local API. A discovery file for another port/address is rejected before fetching
data. A localhost page can use the generated `127.0.0.1` discovery file on the same
port: API requests use relative same-origin URLs, never the supplied URL as a
cross-origin fetch target.

The page initially contains no token or entity data. Authentication is explicit;
the service never publishes its discovery file or bearer through an unauthenticated
route. The token remains in page memory, never the address, DOM, logs,
localStorage, sessionStorage or cookies. **Forget connection**, reload and leaving
the page discard it and clear the views. Invalid/malformed files do not display
their contents. There is no automatic sign-in from browser storage.

The explorer shows current connection/area scope, control and player-character
availability, then paginated/filterable known object references. It reads full
entity data only when selected. Received/known data, client-initialized caches and
sampled presentation retain their distinct provenance; presentation is explicitly
labelled client-simulated/interpolated in NWN coordinates. Received name text can
combine available first/last text; unresolved string references are not guessed.
All server strings and JSON are rendered literally with `textContent`.

Manual refresh is always available after authentication. Optional polling defaults
off, runs no faster than every five seconds, pauses while the document is hidden,
and never overlaps a refresh. Requests are serialized with at least 200 ms between
attempts. HTTP `429` honors `Retry-After` with a bounded retry count. Old entity refs
and cursors clear their views on `410`; they are never retried as a bare reused ID.
Disconnect/re-auth increments an epoch and aborts/ignores older requests so stale
replies cannot refill a locked page.

Only five fixed static paths are public: `/explorer`, `/explorer/`,
`/explorer/app.js`, `/explorer/style.css`, and `/explorer/favicon.svg`. They contain
no credentials. Document navigation must be direct or same-origin; scripts/styles
must come from the same origin. CSP permits only its own scripts/styles/fetches,
forbids inline code, framing and external content, and all assets are offline with
no CDN. Their bytes are embedded in `systems/client_api/explorer_assets.gd`, so
the existing GDScript release pack includes them without export-file exceptions.
Fixed public bootstrap assets do not consume the authenticated data-query token
bucket, so rapid reloads cannot strand a page without its script. They retain all
socket, per-frame byte/request, response-size and deadline caps; `/api/v1` keeps
the same 10/second, burst 4 quota and bearer requirement.

This is an external diagnostic web page over read-only REST. Game rendering, game
UI ownership and gameplay controls remain in native Godot. The running client
was not restarted and has not been hot-patched; the explorer is available from
the updated sources on a subsequent opted-in launch.

The explorer required no additional shared session/project hook. Before changing
HTTP authentication/static handling, the prior transport and documentation were
saved under `.cache/entity-api-explorer-checkpoints/20261102-081447/`.

### PowerShell client (PowerShell 7)

In another PowerShell session after the opt-in client starts:

```powershell
$restDiscovery = Join-Path $env:LOCALAPPDATA 'NWNClient\EntityAPI\discovery.json'
$discovery = Get-Content -LiteralPath $restDiscovery -Raw | ConvertFrom-Json
$base = $discovery.base_url
$headers = @{ Authorization = ('Bearer ' + $discovery.bearer_token) }
$scope = Invoke-RestMethod -NoProxy -Uri ($base + '/scope') -Headers $headers
$controlled = Invoke-RestMethod -NoProxy -Uri ($base + '/controlled?presentation=true') -Headers $headers
if ($controlled.result.available) {
    $reference = $controlled.result.reference_token
    $entity = Invoke-RestMethod -NoProxy -Uri ($base + '/references/' + $reference) -Headers $headers
    $entity.entity.identity
} else {
    $controlled.result.reason
}
```

### Python client (standard library)

```python
import json
import os
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, ProxyHandler

path = Path(os.environ["LOCALAPPDATA"]) / "NWNClient/EntityAPI/discovery.json"
discovery = json.loads(path.read_text(encoding="utf-8"))
opener = build_opener(ProxyHandler({}))  # Always contact loopback directly.

def get(route, params=None):
    url = discovery["base_url"] + route
    if params:
        url += "?" + urlencode(params)
    for attempt in range(5):
        request = Request(url, headers={
            "Authorization": "Bearer " + discovery["bearer_token"],
        })
        try:
            with opener.open(request, timeout=5) as response:
                return json.load(response)
        except HTTPError as error:
            if error.code != 429 or attempt == 4:
                raise
            delay = float(error.headers.get("Retry-After", "1"))
            error.close()
            time.sleep(min(5, max(0.1, delay)))

filters = {"object_type": "5", "current_area": "true", "limit": "25"}
while True:
    try:
        page = get("/entities", filters)
    except HTTPError as error:
        if error.code != 410:
            raise
        error.close()
        print("Area scope changed; restart enumeration.")
        break
    for item in page["items"]:
        try:
            entity = get("/references/" + item["reference"])["entity"]
        except HTTPError as error:
            if error.code != 410:
                raise
            error.close()
            continue  # The entity was removed/replaced after this page arrived.
        print(entity["identity"])
    cursor = page["page"]["next_cursor"]
    if cursor is None:
        break
    filters["cursor"] = cursor
```

Reference behavior follows the native provider: a reconnect, area change,
removal or ID reuse makes the old reference return `410`, even when the new
entity has the same numeric ID. The player-character endpoint continues to
report unavailable identity until an authoritative source establishes it.

## Validation

Run the dedicated no-build runner from the workspace:

```powershell
& .\godot-client\tests\run-native-entity-api-tests.ps1
```

It copies an explicit list of API/test sources plus `network_motion.gd` into a
new isolated project under `.cache/entity-api-tests/`. A third isolated headless
process runs `native_entity_api_session_test.gd` against the actual current
session source with fixture owners; its overridden `run()` opens no connection.
The runner verifies hashes of the API/tests and exact shared hook files before
and after, using the existing `.tools/Godot_v4.7.2-stable_win64.exe` with
`--headless`. It never calls ensure/build helpers, connects to a server, or
touches the release-tests junction. It holds handles only for its own hidden
test processes and bounds them with a timeout. A normal main scene checks the
literal autoload; the SceneTree tests check runtime bootstrap, `access.gd`, and
actual session hooks. Test receipts and engine logs remain in the isolated
directory; the consolidated receipt is
`reports/native-entity-api-v1-receipt.json`, also written as
`reports/native-entity-api-rest-v1-receipt.json` after the complete REST run.

The fourth process runs `native_entity_api_rest_test.gd` against real native TCP
sockets in the isolated project, capped at 60 FPS. It opts in with an ephemeral
port and private fixture discovery path, and removes its token file. The actual
session fixture additionally verifies that REST bind failure cannot invalidate
game/API state or suppress an ACK, and that the real session shutdown entry
closes the service. No test connects to a game server or restarts the user's
client. The latest four-suite receipt records the exact source hashes, terminal
exit codes, individual check counts, engine hash and measured active frame work.

Coverage includes complete/delta queries and filters, previsual/non-renderable
objects, JSON numeric IDs, distinct control/explicit-PC identity and unavailable
PC identity, missing/null fields, removed and cached-removed objects, same-ID
replacement, reconnects, area generations, reset counter persistence, foreign
API-instance references, recursively detached snapshots and events, unsupported
Godot objects/cycles, deterministic atomic event ordering, bounded delta/movement
work, stale movement revisions, and actual native prediction remaining separate
from raw received fields. The actual session test covers accepted and ignored
raw framing, completion/epoch/area observer guards, preserved core application
and acknowledgments, nonfatal binding rejection, bounded diagnostics, both
movement profiling paths, last-raw-state preservation during fast motion, and
reset/shutdown entry invalidation. Live-client/server behavior, rendering, and real possession remain
outside this isolated validation; the current protocol still lacks independent
player-character identity.

Run the separate external browser test with the existing local Godot and
Electron executables:

```powershell
& .\godot-client\tests\run-native-entity-api-explorer-tests.ps1
```

It copies and pins only the API modules and its dedicated test files, starts an
owned native headless fixture on an ephemeral IPv4-loopback port, then uses a
hidden offscreen Chromium WebContents with GPU disabled, sandboxing, context
isolation and Node integration disabled. The test browser has a separate profile
and admits requests only to its owned loopback origin. It never launches or
focuses a user window. This Electron use is a test harness for the external web
page; the product continues to render its game and game UI in native Godot.
An additional never-shown document checks actual hidden Page Visibility state;
the offscreen screenshot document remains logically visible for painting.

The authored-owner browser cases exercise actual file input authentication,
malformed/wrong-port/wrong-token discovery, scope/control/unavailable player
identity, filters and pagination, separate received/presentation views, literal
hostile name text, removal/ID reuse and old cursors, actual HTTP `429` recovery,
polling, cancellation, reload, and localhost-page/127.0.0.1-discovery aliasing.
They verify that bearer data never enters the DOM, URL, cookies or browser
storage, that all bootstrap assets load on rapid reloads, and that no foreign
network requests or unexpected browser runtime errors occur. Private fixture
files are removed; finite sanitized network metadata, engine logs and screenshots
remain under the unique `.cache/entity-api-explorer-tests/` run directory.
`reports/native-entity-api-explorer-v1-receipt.json` records exact source/runtime
hashes and the screenshot paths. This is isolated HTTP/browser validation with
authored canonical owners, not acceptance against the running game client.

The final normal-runtime receipts record **230 native checks** (70 provider,
18 binding, 34 actual session hooks, 108 HTTP) at `2026-11-02T09:23:19Z`, and
**38 browser plus 2 fixture cleanup checks** at `2026-11-02T09:17:45Z`.
All four native processes exit zero, with no engine/script/lifetime errors;
the HTTP transport-failure list and browser runtime-error list are empty.
The browser run completes all 89 accepted sockets with no socket error or
timeout. These receipts pin 19 and 13 source inputs respectively.

For transport diagnosis without preloading any shared session/UI source, use:

```powershell
& .\godot-client\tests\run-native-entity-api-tests.ps1 -HttpOnly
& .\godot-client\tests\run-native-entity-api-tests.ps1 -HttpOnly -TransportFailureProbe
```

The second command intentionally stops its own listener before one request. Its
separate receipt, `reports/native-entity-api-transport-failure-receipt.json`,
requires the classified nonconnected status, exactly one intentional failure,
engine exit 1 and discovery cleanup. The runner exits zero only when this
expected failure is verified; it is **not** part of the normal 230 passed checks.
The final-source probe at `2026-11-02T09:23:33Z` records the unchanged 1500 ms
connect deadline as `TIMEOUT` while still `CONNECTING`. An unexpected transport
failure now writes finite phase/status/listener counters, stops only the endpoint
and exits before a missing response body can trigger another script error.
Diagnostics retain fixed numeric close-reason counters, without request contents,
headers, credentials, entity data or frame histories.

Earlier failed test evidence is retained. Rapid reloads initially rate-limited
the static script/style bootstrap; fixed assets now bypass only the data-query
bucket, and actual browser reload/alias tests cover this correction. Separate
intermittent nonconnected-handshake and browser reset events were not reproduced
after adding bounded diagnostics; their underlying causes remain unclassified.
No transport retry, timeout extension or close delay was added to hide them.
