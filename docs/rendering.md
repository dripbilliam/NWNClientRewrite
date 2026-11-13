# Rendering and presentation

Godot constructs native worlds from original resources. Preserve models, textures, appearance/equipment identity, animation events and active-server resource selection. A frozen GLB import is historical comparison evidence, not the current gameplay pipeline.

## Current boundaries

Original models, GPU skinning, rigid parts, material controllers, scenery streaming, effects and weather have substantial native implementations. `systems/native_render/` contains the active owners; `systems/visual_runtime.gd` supplies procedural effect phases.

| Area | Established scope | Remaining scope |
| --- | --- | --- |
| Visibility | Primary reveal and a real two-account reused-ID lifecycle in reviewed configurations | Full LOS/concealment/vision, physical draw-collected tile/fog boundary and all role/area cases |
| Bridges | Original-asset support fixtures with distinct received/predicted/displayed coordinates | Actual placements, overlapping support ties and idle/server-movement acceptance |
| Door picking/FOV | Actual original-server open/close targeting; saved 45° vertical KEEP_HEIGHT fixtures | Broad doors/overrides, scripted-camera events and matched native-room comparison |
| Highlights | User-preferred single-body glow and large-scene surface correction have scoped pixels | Combined live/normal-configuration confirmation and representative cost |
| Lighting/materials | Same-room comparisons, generated flame lamps, finite-light selection and gameplay profile | Complete time/vision/shadow/material/animated/effect coverage |
| Procedural effects | Model, alpha and beam paths exist | Diagnostic attachment/update/start/stop branches, selected-view effects and camera shake |
| Weather | Original rain/snow render | Lightning/audio/timers, broad transitions and retained cold-shader fault investigation |

The unconnected tile-fog lower retains its working default factor 1. A collector file or isolated kernel is not activation. Do not replace missing native collection with guessed room hiding.

The large-area black-surface regression was reproduced as exhausted instance-uniform capacity, including with Tab released. The correction avoids allocating inactive tile-fog uniforms. Do not dismiss black scenery as a highlight artifact or assume isolated pixels establish the user's live result.

## Particles

The compiled existing particle path has accepted components and remains distinct from the GPUParticles3D replacement. Existing replacement work is tracked under [NWN-5](https://linear.app/nwnanalog/issue/NWN-5), with family integration, rollback, visuals/performance and final acceptance under NWN-6–12. Avoid duplicating those tickets.

Preserve native clocks, random draws, attachments, tint/fog/gamma, collision/bounce, texture lookup, transparency order and lifecycle. Do not claim a backend complete with a missing family or disabled effects. Verify effective settings: a saved/default-off particle preference is not full-effect acceptance.

Build/arithmetic details remain in the [extension reference](../godot-client/native/README.md). Performance is in the [performance guide](performance.md); remaining visual work is NWN-46 and NWN-48–52 in [parity](parity.md).
