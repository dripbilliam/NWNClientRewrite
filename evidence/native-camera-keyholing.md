# Native camera keyholing — 2026-10-18

This continues the normal-camera parity work in native-gameplay-camera.md.
The full multiplayer goal remains active. Original binaries, Ghidra project,
assets and original client are read-only inputs.

Target nwmain89.8193.37-17, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Read-only REA dossiers: backups/animations/rea-camera-keyhole-*.json.

Observed native behavior:

- Camera::RenderScene14005a5d0 enables keyholing when shader integer globals8
  and9 are enabled and the camera has a Scene. It derives a plane from the
  camera near plane and camera-to-player distance, and a height threshold from
  Scene player Z plus shader float23. Algebraically the plane points forward
  through the camera-to-player distance. The JS plane uses that derivation;
  the complete native RenderScene has not been executed as an oracle.
- Camera::GetCanKeyholeDissolve140058c50 requires enabled, Part field50 null,
  bbox maximum Z strictly above the height threshold, and a negative
  BoxAbovePlane14022b350 result. Part::GetAurObject140061af0 identifies field50;
  physical parent field48 is a different relationship. BoxAbovePlane selects
  the corner with minimum signed distance. These two complete native functions
  execute against synthetic state in inspect-native-camera-keyhole.py;
  all756 observations agree with camera_keyhole.js.
- Scene::AddPartsToDrawBuckets1400c38f0 and RenderDrawBucket1400cd210 move
  eligible opaque parts to the dissolving path and set the per-part shader
  can-dissolve flag through RenderInterface::SetCanDissolve1400bf010.
- Installed shader resources use type2069. The active resolver supplies
  inc_keyhole and its common/config/uniform/random includes. The native shader
  computes depth/pitch-adjusted screen radius, original 3D noise, world-height
  cutoff, darkened edge and discard. It executes after material lighting and
  before output color conversion/fog. Source assets remain in the installed
  archives and are expanded only in memory; none are copied into the repo.
- Native settings registration1406b3295 stores enabled default1. Diameter
  defaults are float.4/.9 at140e2c9a8/140e2c9b0; minimum Z offset defaults1
  through XMM10. The relevant read-only disassembly is retained. User profile
  camera preferences are not imported.

Renderer adaptation and its limits:

- Shared SP/MP presentation loads through the active area resolver. Native
  uniforms receive drawing-buffer dimensions, native world/view axes, player
  position, camera pitch and follow distance. Desktop declaration precision
  syntax is normalized for WebGL and declarations/macros/functions are
  namespaced, preserving the discard keyword and executable shader math.
- Static tile model meshes are tagged when instantiated. Placed objects,
  creatures, doors, debug geometry and particles are excluded. This mapping
  represents the native null-AurObject gate using current renderer ownership;
  every possible original Part ownership path has not been reconstructed.
- Each tile mesh clones its material so repeated instances cannot overwrite
  another part's flag. Area cleanup restores original material/render callbacks
  and disposes the clones. Program cache keys include active shader source hash.
- The network resource bridge now permits named SHD2069 requests through its
  existing validated resource-name/type gate. It still rejects filesystem
  paths, unknown types, unavailable sessions and stale session ownership.
- Camera collision/path queries, legacy wedge fading, complete scripted camera
  interpolation/locks and configurable native input mappings remain open. This
  change does not claim complete camera or multiplayer parity.

Validation:

- Native oracle756 cases;213 focused network/camera/feedback checks PASSv3.
  The final bridge/resource regression run is recorded separately in v4.
- Independent GPU fixturev3 verifies red occluder -> green player center
  pixels. v4 repeats with the actual MeshLambertMaterial class: disabled
  [250,0,0,255], enabled[0,255,0,255], ownership untouched and cleanup restored.
  Original shader source is passed in memory, never saved by the fixture.
- Full Prelude smokev1 exposed an attribute name collision with Three vNormal.
  Fixed by namespacing native attributes. Smokev2 follows actual authored Pavel
  dialogue to entry33/script mode1 with no shader error. Its final detached
  model-preview camera has keyholing disabled, so that screenshot does not
  establish gameplay keyholing. The post-exit GPU teardown warning is retained.
- Separate normal-gameplay smokev3 loads263 tile meshes, keyholing enabled,
  83 eligible meshes, no stderr; screenshot inspected and the foreground
  occluder dissolves. Startup is disabled and manual preview sun enabled in
  these isolated fixtures; no campaign-completion claim.
- Owned vanilla server restart20964 was necessary after the prior server22040
  and replacement21088 process handles were verified absent. Native discovery
  confirms Prelude, ELC enabled, local vault, maximum2, no players before test.
- Actual multiplayer v74 connected, exercised all camera modes and two movement
  requests, then closed cleanly. It exposed SHD2069 missing from the resource
  bridge whitelist: camera.keyhole-load-failed was recorded. This is failed
  keyholing evidence, not acceptance. v75 reruns after the whitelist fix.

No local multiplayer simulation, canonical object mutation or gameplay results
are introduced by camera presentation. Full end-to-end multiplayer alongside
original clients still requires its broader combat/casting/interaction gates.

Final bridge/resource suite216 PASSv4; buildv4 PASS with the existing bundle
size warning. Actual unchanged vanilla-server runv75:133 camera/keyhole
samples, all3 modes,20 distinct rendered anchors,2 movement requests,4 actual
orbit/mode UI actions,113 enabled keyhole samples, eligible count0..79,
no sample failure and no runtime errors. Top-down/orbit screenshots inspected:
the foreground beam dissolves around the player. v75 closed through normal
disconnect. This is a replacement/vanilla-server check, not a new concurrent
original-client playthrough. Full capture and diagnostic summary are retained.

Interactive updated clientv76 PID37376 is OPEN on owned server20964. No
automated inputs were configured. Passive frozen snapshot confirms loaded/
enabled keyholing on263 tile meshes and camera target following the displayed
controlled PC, with no sample failure. The user is moving/orbiting; do not
recenter, close or reconnect it while testing. Continuously changing live JSON
and interactive stdout/stderr are excluded from the checkpoint. Normal close
is available through backups/animations/network-renderer-control-v76.json.
Credential audit13,323 source/evidence/build text files: private credential
hits0. The final frozen snapshot and ready screenshot are safe to archive.

Checkpoint multiplayer-native-camera-keyholing-20261018-v1.zip sealed and every
entry length/SHA256 verified:13,503 files/295,099,521 bytes. Scope audit27
required present, forbidden0;13,504 entries including manifest. Writer48758
terminated0 and was consumed. Scope audit and this postseal note remain outside
the sealed archive. Full goal remains ACTIVE.
