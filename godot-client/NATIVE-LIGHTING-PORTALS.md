# Native lighting and portal interaction, 2026-10-24

Migration remains active/incomplete. This fixes specific lighting and picking
losses, not full atmosphere, multiplayer, rendering or performance parity.

The user manually connected Godot to PGCC. Retained status
`reports/public-browser-1792832126645.status.json` records all 97,820 resources
available with zero downloads, server-vault selection and playing `gs_enter`.
The user's screenshot confirms presentation but exposes darkness and missing
portal interaction. This is observed public admission, not broad acceptance.
The user then prohibited online connections until returning. Process inspection
confirms the public replacement ended; subsequent checks are offline/localhost.
The editor was preserved. Explicit public startup remains user-directed, with
unrestricted addresses; ordinary test startup remains loopback-only.

## Corrections

Three directional/spot lights face a target, while glTF uses local -Z. Exporting
only the original matrix lost the sun's direction. The exporter now resolves
world target/position, including transformed parents, without altering source
lights. Ambient RGB was already linear but Godot converted it from sRGB again,
darkening it. Native loading now supplies the expected input color space once.
The solid source background also survives. See the installed Three exporter,
Godot's [glTF adapter](https://github.com/godotengine/godot/blob/master/modules/gltf/extensions/gltf_light.cpp)
and [environment conversion](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/renderer_scene_render_rd.cpp).
Models, textures and UVs are preserved; no universal light is invented.

Late type-7 transitions now enter the native content update path. Their pose
uses the polygon center and native +0.05 picking lift, instead of generic
position updates lowering the surface into terrain. Actual hidden render-zero
trimeshes of usable type-9 placeables also export as transparent picking
geometry. Source material visibility stays unchanged; unrelated hidden or
unusable objects receive no invented geometry.

Actual local clicks exposed a shared backend bug: movement approached a trigger
without its selected object ID, so the server never activated the transition.
Original click `1406f02c0` copies the non-trap trigger ID to R12D at `1406f0660`,
passes it at `1406f0cf3` to `1406f3650`, then sender `1407c0970` at `1406f3b98`.
The existing waypoint packet now retains that target and movement sequence.
The server still owns approach/scripts/transition, with no local teleport.
Static evidence: `reports/native-trigger-selected-id-evidence-v1.json`, derived
from the retained dossier and its digest. Original NWN:EE89.8193.37-17 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binary, process and Ghidra database were not modified.

## Verification

* `reports/portal-region-local-v8.json`: 14 native checks over three animated
  admissions. Actual mouse clicks cause server-owned A → B → A, exactly two
  interactions and three generations. Retired-owner counts 0/6/12 all have zero
  survivors. Exit 0, clean disconnect. The dedicated evidence gate accepts this
  actual report and rejects 15 missing/stale/failure mutations.
* Authored `GodotPortal1` module SHA256:
  `398a09c4dc192f4e4d128e792ffeae1382cde3b925bd49d4ad204fd9e042a45c`.
  Original art is referenced by name only. Ordinary `GodotFeedback1` restored.
* `reports/lighting-portal-native-v3.json`: 11 Vulkan checks through the actual
  exporter/native loader for direction, ambient/background conversion, invisible
  trigger/hidden-placeable picking, highlighting and released physics owners.
  The rendered PNG was generated; the earlier v2 PNG was visually inspected.
* `reports/lighting-portal-local-v2.json`: 16 real server dialogue/examine checks,
  animated movement, bridge v35, exit 0 and clean disconnect.
* `reports/native-lighting-portals-backend-v2.log`: 110 tests pass, no skips or
  failures. Verbose portal logs retain unrelated Vulkan overlay-loader warnings.

Failed attempts remain unaccepted: native v1 strict test type error; local
portal v1 cleanup count/array error; v2/v3 lowered surface; v4/v7 missing target
ID timeouts; v5 null-network diagnostic startup stall; v6 existing-game guard.
Only the specifically verified v5 test owner/orphan was stopped. No other
game/editor was killed. The v5 diagnostic guard was corrected.

## Remaining

Fog, skyboxes, weather, dynamic day/night light interpolation, point attenuation,
complete shadows and ambient-material weighting remain unfinished. So do exact
native terrain-resampled hit priority and user verification of actual Arelith
portal use/dialogue. Cross-server handoff is still disabled; the prior optional
IPC/lobby foundation is backed up as WIP. Full migration and moving complete
captured/local-scene 60 FPS remain unaccepted. Small-room FPS proves neither.

To rerun, start owned `GodotPortal1`, then
`./godot-client/join-local.ps1 -PortalRegionSmoke -NativeVerbose -Report <new-name.json>`.
Restore `GodotFeedback1` afterward. No public connection is needed.
