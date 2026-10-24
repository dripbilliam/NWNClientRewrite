# Native engine migration and acceptance

Latest architecture instruction: Godot is to own all runtime systems natively.
The JS scene/export/network bridge described below is transitional, not the
final architecture. See [NATIVE-OWNERSHIP.md](NATIVE-OWNERSHIP.md) for native
resource/model/worker implementation evidence and the remaining conversion.

User authorized native-engine work in this new top-level folder on 2026-10-22.
The existing native-rendering-parity goal remains active and incomplete.

Latest user clarification: **the textures and models must remain the same;
some visual difference is acceptable.** Godot's lighting, shadow appearance,
tone mapping and similar engine presentation may differ. This supersedes an
exact framebuffer-match requirement for the native migration. Preserve source
geometry, UVs, texture artwork, equipment/appearance selection and functional
animation/effect behavior. Missing parts, broken alpha/blending and altered
mapping remain import defects, rather than acceptable lighting differences.

The first bridge loads the complete decoded captured world in the existing
offline resource frontend, transfers its source-visible meshes and captured
camera once, then exits Electron. Godot owns subsequent native scene rendering.
Runtime GLB/texture data is written only to an external temporary directory.
An empty or incomplete frontend must fail before a bundle is accepted.

The glTF bridge deliberately records fidelity gaps. Stock engine lighting can
be retained under that clarification, subject to visual review. Rebuilt image
mips, frozen deformed geometry/particle poses, broken blend modes and absent
gameplay still need work. An import establishes that the engine works; its
FPS cannot establish a full-game improvement. No new renderer is promoted and
the >=60 FPS goal is not completed by this prototype.

Next acceptance work:

The first native systems pass is complete: entity registry/identity, precise
occluded picking, hover/Tab highlighting, inspection camera input, independent
draggable read-only panels and particle blend adaptation. See [SYSTEMS.md](SYSTEMS.md).
The complete-world smoke and authored checks pass. The owned local-server
bridge now joins Prelude, imports its actual area, streams authoritative
object transforms, and sends movement, interaction, chat and conversation
replies. See [LOCAL-MULTIPLAYER.md](LOCAL-MULTIPLAYER.md). Native rigid/skeletal
playback now passes authored GPU and real local body/robe locomotion checks;
see [NATIVE-MODELS.md](NATIVE-MODELS.md). Per-object native content replacement
now passes real local shape/clothing/spawn/removal checks; see
[NATIVE-WORLD-LIFECYCLE.md](NATIVE-WORLD-LIFECYCLE.md). Particles, event/controller
effects, full equipment/mount coverage and the full gameplay UI remain pending.

1. Confirm the 898-object canonical inventory and every transferred mesh, UV,
   material group, transform and captured camera. Match the 1424×921 buffer,
   MSAA, shadows and visibility; compare screenshots and counts explicitly.
2. Audit original geometry/UVs and texture identity through transfer, preserving
   authored image data and render semantics. Fix particle transparency/additive
   blending and appearance/equipment defects. Godot lighting/shadows are allowed;
   port NWN-specific material/effect rules where needed to preserve content or
   functionality, rather than requiring an exact old-renderer pixel match.
3. Transfer moving world state as compact updates and let the engine own scene
   changes, camera, culling, skinning, bounds and GPU resources. The JavaScript
   resource/protocol work is reusable; Three scene traversal is not the target
   native frame loop.
4. Implement animated particles, skeletal animation and attachments. Validate
   sparse 64-bone palettes, authored normals, zero/nonunit weights, picking,
   shadows, mounts and shape changes against retained native evidence.
5. Restore gameplay/UI behavior: navigation/input, targeting/highlighting,
   inventory/spells/character sheet, NUI, conversation and all network updates.
6. Use owned local servers and captured scenes only. Preserve user sessions;
   no Arelith connections. Measure complete moving scenes, loading, repeated
   transitions, steady-state average/p95/worst and resource cleanup separately.

Require sustained >=60 FPS and p95 <=16.7 ms with model/texture integrity,
acceptable engine presentation and complete gameplay
acceptance before promotion. Keep failed runs, engine approximations and
unsupported content visible in reports. Make verified project checkpoints at
significant changes using `./tools/checkpoint.ps1 -Name <unique-name>`.
