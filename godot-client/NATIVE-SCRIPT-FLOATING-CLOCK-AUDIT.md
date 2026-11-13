# ScriptFloating object-clock audit

Read-only audit, 2026-11-04. Production, tests, native binaries and running processes were not changed. No engine, oracle, server, connection or benchmark was run. This document is the only new workspace file for this audit.

The current remote Godot path supplies a **nominal movement-frame millisecond delta**, not the original per-object selected clock. The native protocol already has the pause-state message needed to drive the selection branches, but the remote decoder does not admit that message and no remote owner maintains its flags, exclusion list, three client clocks or object reset stamps. Calendar state, GUI timing bars, visual effects and local server simulation cannot fill those gaps.

## Original owner and units

Pinned original: `FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. Addresses below are relative to the image's usual `140000000` base. Full retained object/FIFO/frame evidence is in [the lifecycle dossier](reports/native-script-floating-lifecycle-log-addendum-v1.json), with [the earlier clock proof](../evidence/client-pause-clocks.md).

Do not confuse the same offset on different owners:

| Owner/field | Type and meaning proved by its consumer |
| --- | --- |
| Client `+4c8` | BYTE flags; selector tests bits `2` then `1`. |
| Client `+4d0` | Pointer to one shared received OBJECTID list. Null and present-empty differ. |
| Client `+50`, `+58`, `+60` | Three `CWorldTimer*` pointers, named `T0`, `T1`, `T2` here. These are not elapsed millisecond fields. |
| Creature `+50`, `+54` | Previous absolute DWORD day and DWORD millisecond-within-day stamps. |
| Creature `+58` | DWORD elapsed **millisecond remainder** written by AIUpdate. Whole elapsed days are not added to it. |
| Object `+98` | Signed int32 pending-floaty cooldown, constructor value `0`. Its subtraction wraps as DWORD arithmetic. |
| `CWorldTimer` counters | Integer microsecond counters; `GetWorldTime597180` divides by `1000`, then normalizes day/within-day offsets. `minutesPerHour` controls day length. |

`6ab840 → 6d7fe0` takes the actual object's external client ID. The omitted argument in some decompiler calls is not an implicit global selection: assembly and fresh `6dab20` show the ID argument and exact membership comparison.

```text
selected(id):
    if id != 0x7f000000:
        if flags & 2:
            if member(id): return T2
        else if flags & 1:
            if member(id): return T1
    return T0

member(id):
    if list pointer is null: return 1
    return 1 only for an exact DWORD ID in the present list
```

Bit `2` has priority; a nonmember under bit `2` falls to `T0`, even if bit `1` is also set. A present empty list admits no IDs. `OBJECT_INVALID` always selects `T0`. These neutral field names deliberately avoid deriving server effect, immunity or privacy semantics from bits alone.

## Received state and transition order

Original dispatch `7a41a0 → 7a4d30`, case `9`, invokes `7a5680`: **major `3`, minor `9`**. The original sender `4dd0c0` emits a two-bit BYTE mask, BOOL value, WORD count and that many OBJECTIDs. The client allocates its own list, reads every declared ID, checks overflow, and only then applies the state. Native packets do not send three absolute clock snapshots or creature elapsed stamps: those are client presentation owners.

`6e1fc0` is not equivalent to assigning a Boolean paused flag:

1. Compare raw `(flags & mask)` with the integer value. Only exact `value == 1` takes the ON branch. A repeated `mask=2,value=1` still executes because `2 != 1`.
2. Perform the original timer/flag transition. ON pauses `T0` and snapshots it twice; when resulting bit `2` is set it also pauses/snapshots `T1` twice. OFF mask `2` resets `T2` from `T1`, snapshots and synchronizes the relevant counters, conditionally resumes `T0`, then resumes `T1/T2`. OFF mask `1` resets both auxiliaries from `T0`, snapshots/synchronizes all three and resumes them. The full ordered port is already in `src/client_pause.js`; snapshot/reset/unpause calls must not be coalesced.
3. `6d6770` visits **the old list using the new flags/timers**, reads each object's newly selected time, invokes its reset virtual `+10`, then scene virtual `+158`; only afterward does it clear/free the old list buffer. It re-reads the live count after callbacks.
4. Append each incoming unique ID. Duplicate IDs are not appended twice, but still perform object/scene/reset work. For every found object, scene virtual `+150` precedes active-time reset. Creature reset `807680` writes only its previous day/time stamps. Base reset `2964d0` is a no-op; other object types must not be assigned the creature override without proof.

The original client keeps **one received list**, unlike the local authoritative server's two separate lists. Client state cannot be reconstructed from the currently visible caster, spell ID, effect icons or membership in the local scene.

Creature `7fbd10` samples its selected time, subtracts previous `+50/+54` through `SubtractWorldTimes597a20`, and stores only the unsigned millisecond remainder at `+58`. Later in that same AI update it samples selected time again and stores the new previous pair. FIFO `766e20` consumes this object elapsed value: if cooldown is positive, subtract and do not activate that update; otherwise activate at most one pending widget and write `400`. Crossing positive to zero does not activate until a later object update.

Object manager `767d50` runs before GUI update in client frame `6db800`, so a newly activated widget receives that same GUI frame's update. Active widget lifetime/rise/fade uses its separate GUI delta, not its source object's FIFO delta. There is no mesh-loaded, culled or offscreen early return before the creature queue except actual eligible object destruction. A missing current source is not permission to fabricate an object update.

## Current remote data and owners

| Current input/owner | What is actually available | Why it does not reproduce the selector |
| --- | --- | --- |
| `network_game_messages.js`, module `3/1` | Module `minutesPerHour` BYTE plus module metadata. | Rate is useful, but supplies no pause transition or exclusions. |
| `network_area.js`, initial area time | `timeOfDay`, DWORD `transition`, `hour/day/month/year`, `dawn/dusk`. | Calendar/sky state is not flags/list or the three clocks' transition history. |
| Module `3/3` | Masked time-of-day/transition, hour/day/month/year updates. | No mask/value/exclusion payload from `3/9`; no per-object reset stamp. |
| GUI `48/1` | Active BOOL, optional DWORD duration and BYTE type. | This is a server timing-bar message, not the object-clock selector. |
| `NetworkWorld.time` | Area-time copy and later calendar merges. | No pause-state application, three-clock owner or reset callbacks. |
| Host raw-world/`EnvironmentDelivery` | Calendar/module state; visual sky transition elapsed using a local monotonic timestamp. | Visual environment interpolation does not own native object elapsed time. |
| `NetworkMotion.update` | `dt = int(seconds*1000 + remainder_ms)`; retain fractional remainder and current process-frame number. | One shared nominal quantum for all objects; no selected timer, flags, membership or per-object previous pair. |
| `native_script_floating_object_delta` | Current source/lifetime/scope guard, then current-frame `NetworkMotion.last_delta_ms`, otherwise null. | The guard prevents stale data, but cannot distinguish clock branches. Its comment correctly states this limitation. |

`network_game_messages.js` currently recognizes module `3/1` and `3/3` and rejects `3/9` through its `unsupported` admission branch. `NetworkGameSession` diagnoses `network.game-message-unhandled`; `NetworkWorld` has no pause message owner. Host's decoded UI-event whitelist and raw-world snapshot do not publish pause state. The scene-capture kind whitelist does not retain a decoded pause event either. This is a concrete remote decoder/state/transport omission, not evidence that the original wire format lacks the data.

There is original-backed reusable code in `src/client_pause.js` and `src/world_timer.js`. However, `ClientPausePresentation.initialize()` currently reads `ModuleSession.worldTimer`, its scheduler and local registry; `ModuleSession` sends a typed local `module-pause-state` event. That path is a local authoritative simulation and historically validated browser presentation. It is **not** the received multiplayer session and must not be imported as the remote server's authority. Its ID conversion and object mirrors also need the remote namespace/lifetime boundary, not a second conversion of already-external IDs.

## Concrete missing boundary for a future implementation

No production change is proposed for this frozen authority run. A later scoped implementation would need:

- Strict remote `3/9` decoding into owned scalar/list data, preserving original widths, ordering and malformed-packet rejection; no control command to the server and no effect-derived fallback.
- A connection-owned client clock projection initialized at the verified native module/client-clock lifecycle. It must preserve `T0/T1/T2`, raw flags, null-versus-empty shared list, monotonic snapshots and original reset/unpause order. Unknown received state must not be represented as native null-list membership, which admits every ID. Calendar data can configure known fields; it cannot recover missed pause history. The complete initialization/resynchronization path is not newly proved by this bounded audit.
- Ordered pause delivery to the native presentation owner, independently of asynchronous visual/model publication. Existing raw-world batches alone are not a substitute for old-list/new-list callback order.
- Per-object previous day/time stamps and reset dispatch bound to canonical reference, disclosure lifetime and connection/world scope; discard stamps on true retirement/reuse. A missing exclusion object is skipped at that transition, as native does, rather than silently inventing a reset for a later new lifetime.
- An object-frame delta provider that consumes the selected clock once in the proven object/GUI order, while keeping active widget GUI lifetime separate. Do not freeze active widgets by merely returning zero for the pending FIFO.
- Explicit handling of backwards-clock subtraction. Original `SubtractWorldTimes` can return `-2` without writing output, while its caller copies scratch anyway. Existing local presentation diagnoses and rebases; that recovery is not deterministic original stack parity. No zero/clamp/rebase should be silently advertised as exact native behavior.

The evidence is sufficient to identify the missing remote owners and reuse the tested algorithms. It is not acceptance of received pause packets, special-clock FIFO behavior, other object reset overrides, or a complete timer integration. Current ordinary unpaused/nominal presentation remains its existing scoped acceptance.

## Evidence and verification scope

Fresh read-only REA queries for this audit:

| Original function | Evidence ID |
| --- | --- |
| `6dab20`, exact shared-list membership | `ev_a2e5513c79025bfedb33c5f430d5407f8df7ebf4229fa43fab766d9744cc8094` |
| `7a5680`, module pause receiver | `ev_6375b97c6a365b17ab4d2987e7254bc6df14491f17b530cbf1d26f101e982628` |
| `6e1fc0`, ordered state/timer transition | `ev_1300a4af0ab6d2c1f2a785c88b38d3cb3e14dc068ee7f9b8880b1ecc8c5a4645` |
| `6d6770`, old-list reset and clear | `ev_95c199a64e58da13ca34221a894c9561c947b0a782e820cfc585c83bcca9c6dd` |

Retained lifecycle evidence includes selector `6d7fe0` (`ev_e4e4b15de3f8f7af01b460104c70c16c3311b537fda1d8112d89b6c9d24d7077`), creature AI `7fbd10` (`ev_bb7f096a9435c73d7e1523eee666c269d95de10f0d9fb4de42438a54184b2833`), timer read `597180` (`ev_b18193b09ec3fc1979382ac6cdb093cd7a30655100d185bcfb66d3b47d704864`) and subtraction `597a20` (`ev_618bf07d7b41ffe331b3406f1676042a54845912ec871a79dbe911623205e926`). The earlier clock dossier records bounded original executions; none were rerun for this audit. Source inspection and file hashing are the only workspace operations beyond creating this document.

### Inspected source hashes

Recorded below after the read-only inspection; these identify this audit's source revision, not a claim about later edits.

| Inspected file | SHA256 |
| --- | --- |
| `src/network_game_messages.js` | `8382ef0c13cdd58a6f876502dc72ba00fbf0f8b4b9b716b04f0f1cdf4a5bcf4e` |
| `src/network_area.js` | `735b577c3b25f15962bfc651a28242c18f5a1d8d981813021a566fa1e3f5da48` |
| `src/network_hud_messages.js` | `bffee23de8c3c6f6870145de5a53c93df7f02e4ad16b3177977c76f1a7639608` |
| `src/network_world.js` | `e77dd228655b95987dd00d41b2c3867d7e84c8bb93989cb075bf093b3a7d8331` |
| `electron/network_game_session.mjs` | `5a11fb8bf689e77f0122881dcc2453b5da24dc6f8e88791b93482d270438f711` |
| `electron/scene_capture.mjs` | `072dcf8d51f7a5addfefc73de76aa0d00d0dfb65de4b8935f8664ed34b9361b5` |
| `godot-client/tools/native-session-host.cjs` | `8542e987f91967e0631c63ce29d8f7df8c15ba07e71edf009b691ae4500d87ff` |
| `godot-client/tools/environment-delivery.mjs` | `dc844230db4dc321a9ee923fc502afcc4e308b5d2ee0ff1ad2ead647e463cdf5` |
| `src/client_pause.js` | `4cdd30af544c1e2fa3736ce636672b6f3a27841654acb6cf39ffb7a9a5c1d725` |
| `src/world_timer.js` | `57b7b7fcb3afa8171b60956bd9dbed548c29ce3a7ba1ba25a7a2e3d96668618c` |
| `src/client_pause_presentation.js` | `e849cbd011ca54c07d27e7dd65cd55aff0d4be1579d322d07802137e814145aa` |
| `src/module_session.js` | `43c8e96dc1ecd10892d004a09806da8d1a80a26dbed97695f98d3d476d547a12` |
| `godot-client/systems/network_motion.gd` | `086c3e6693f7b858519820c5539496090de51656de990ef0ee972e866877092d` |
| `godot-client/systems/native_render/live_world.gd` | `c12c8f98765011fffeacb947e71ebf739a8aafc17cc72b6499826a08487904f1` |
| `godot-client/native_live_world.gd` | `ef982eb2721f750c2b24dfee9ea9df6db588cb7cdb87f967620d1b7759aa0342` |
| `evidence/client-pause-clocks.md` | `a69d7ade0b3d0c6b90c01bedeae09ab787d41af20cd4ed6764aacfaa7875ca23` |
| `godot-client/NATIVE-SCRIPT-FLOATING-LIFECYCLE-ADDENDUM.md` | `1dbbe8a88fd94a5debc75a50af921290d28b052fe27c8ac6cf9f24851545b1f9` |
| `godot-client/reports/native-script-floating-lifecycle-log-addendum-v1.json` | `4a7b42f24f39801acb690df3192e51752a95bf87cb0a66a15c85b575b1f0a3bc` |
