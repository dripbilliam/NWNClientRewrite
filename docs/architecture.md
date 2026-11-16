# Architecture and ownership

The active frontend is native desktop Godot. Electron is no longer installed for the normal client; historical frontend and harness sources remain during NWN-79 migration. The intended final application is fully native, and transitional JavaScript protocol services are unfinished migration work.

## Normal runtime

`godot-client/join-native.ps1` currently starts one transitional Node protocol host, which starts Godot. Godot opens Main Menu and owns the protected settings endpoint; the user chooses a server. NWN-79 now requires Godot to own the normal protocol, downloads and world state as well. Native rendering constructs the world from original resources rather than converting an entire area to GLB.

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

Godot handles settings and current-user protected keys through a narrow Windows DPAPI helper. The Node protocol host currently prepares initial paths and imports old Chromium-protected keys, then sends settings requests to Godot over the authenticated local connection. Node still owns the normal playable session's game/world message flow. A separate Godot-only path now has live evidence for Arelith login, server resource requirements, installed-content admission, verified HTTP NWSync downloads and the server-vault character list. It is not yet the normal runtime. NWN-79 remains incomplete until Godot owns that full runtime, historical Electron workflows are retired, and the acceptance matrix passes. A retained Node process requires a specific documented technical necessity.

## Ownership rules

The original server decides rules, scripts, HP, inventory, action results and progression. Native menus may propose actions and privately prepare drafts; they must display the received result rather than fabricate success.

Retire asynchronous work by connection, area generation, actor/model lifetime and resource catalog. Reused numeric object IDs are not new identities by themselves. Keep received state, private presentation state and diagnostics distinct.

Original resources, active-server precedence and physical table IDs are part of compatibility. Engine-lighting differences are allowed only while gameplay visibility, targeting and information remain correct.

The native [entity API](../godot-client/ENTITY-API.md) describes handles, events and inspection. [Networking](networking.md) and [resources](resources.md) describe the remaining boundaries. Full offline simulation and removal of services follow multiplayer acceptance; see [parity](parity.md).
