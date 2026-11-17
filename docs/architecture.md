# Architecture and ownership

The supported client runs in native desktop Godot. Its normal launch path does not start Node or Electron. Historical JavaScript implementation files remain temporarily as read-only references while NWN-79 ports the remaining behavior.

## Normal runtime

`godot-client/join-native.ps1` forwards ordinary launches to `join-godot.ps1`, which starts `native_direct_session_world.gd` in Godot. Godot opens the Main Menu and owns server authentication, transport, resource admission and NWSync, replicated world state, gameplay UI and rendering. Native rendering constructs the world from original resources rather than converting an entire area to GLB.

| Owner | Responsibility |
| --- | --- |
| `godot-client/native_direct_session_world.gd` | Normal Godot session entry, server chooser, protocol lifecycle and world admission |
| `godot-client/native_session_world.gd` | Shared session/world presentation services and accepted snapshots |
| `godot-client/native_live_world.gd` | Live frontend entry and native world integration |
| `godot-client/systems/native_data/` | Original-server transport/session, resource catalogs and decoding, replicated state, table-driven rules and preparation |
| `godot-client/systems/native_render/` | World admission, models, animation, effects, collision and rendering |
| `godot-client/systems/native_game_desktop.gd` | Gameplay UI, input and scoped action dispatch |
| `godot-client/native/` and `tooling/native/` | Compiled extensions and native content, crypto and protected-settings helpers |

Godot owns settings and calls a narrow Windows helper for current-user protected keys. Existing nonsecret settings import once; a legacy saved key may need re-entry. The Godot-only path is the normal runtime and has private acceptance evidence for authentication, character selection, NWSync, gameplay, travel and reconnect. NWN-79 remains open for full feature and public-server acceptance and retirement of obsolete source and delivery paths.

## Ownership rules

The original server decides rules, scripts, HP, inventory, action results and progression. Native menus may propose actions and privately prepare drafts; they must display the received result rather than fabricate success.

Retire asynchronous work by connection, area generation, actor/model lifetime and resource catalog. Reused numeric object IDs are not new identities by themselves. Keep received state, private presentation state and diagnostics distinct.

Original resources, active-server precedence and physical table IDs are part of compatibility. Engine-lighting differences are allowed only while gameplay visibility, targeting and information remain correct.

The native [entity API](../godot-client/ENTITY-API.md) describes handles, events and inspection. [Networking](networking.md) and [resources](resources.md) describe the remaining boundaries. Full offline simulation and removal of services follow multiplayer acceptance; see [parity](parity.md).
