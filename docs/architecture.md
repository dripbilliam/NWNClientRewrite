# Architecture and ownership

The active frontend is native desktop Godot. The Electron/Three.js client is retained for reference and regression work. The intended final application is fully native; transitional JavaScript services are unfinished migration work.

## Normal runtime

`godot-client/join-native.ps1` starts the protected bootstrap and session host. Godot opens Main Menu; the user chooses a server. Native rendering constructs the world from original resources rather than converting an entire area to GLB.

| Owner | Responsibility |
| --- | --- |
| `godot-client/native_session_world.gd` | Session entry, accepted snapshots, menus and connection lifecycle |
| `godot-client/native_live_world.gd` | Live frontend entry and native world integration |
| `godot-client/systems/native_data/` | Catalogs, resource decoding, table-driven rules and preparation |
| `godot-client/systems/native_render/` | World admission, models, animation, effects, collision and rendering |
| `godot-client/systems/native_game_desktop.gd` | Gameplay UI, input and scoped action dispatch |
| `godot-client/native/` | Compiled extensions and their ABI/build contracts |
| `godot-client/tools/native-session-host.cjs` | Transitional host, transport and native process coordination |
| `electron/network_game_session.mjs` | Original-server session, canonical replication and requests |
| `electron/network_peer.mjs` | Authentication, encrypted transport and reliable delivery |

Windowless Electron still unlocks Windows-protected settings and credentials. Node still owns protocol encoding/decoding, authentication, downloads and state transport. These dependencies do not mean presentation or creation rules are browser-rendered.

## Ownership rules

The original server decides rules, scripts, HP, inventory, action results and progression. Native menus may propose actions and privately prepare drafts; they must display the received result rather than fabricate success.

Retire asynchronous work by connection, area generation, actor/model lifetime and resource catalog. Reused numeric object IDs are not new identities by themselves. Keep received state, private presentation state and diagnostics distinct.

Original resources, active-server precedence and physical table IDs are part of compatibility. Engine-lighting differences are allowed only while gameplay visibility, targeting and information remain correct.

The native [entity API](../godot-client/ENTITY-API.md) describes handles, events and inspection. [Networking](networking.md) and [resources](resources.md) describe the remaining boundaries. Full offline simulation and removal of services follow multiplayer acceptance; see [parity](parity.md).
