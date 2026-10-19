# Native camera polygon tests — 2026-10-18

Full multiplayer goal remains ACTIVE. This replaces the approximate camera
triangle-crossing primitive and preserves original model hit geometry. It is
not a complete native BSP, collision-recovery or camera visual-parity claim.
Read-only nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

Native evidence and implementation:

- polyhit140231810..140231a99 tests a cached face plane, rejects back-to-front
  and coplanar/equal-distance segments, interpolates a plane intersection, and
  checks every edge's cross product against the cached normal. Edges and
  segment endpoints are inclusive. SSE instruction order matters: start/end
  dot products differ in addition order, as does interpolated Z. The complete
  finite path is now implemented in native_polygon_hit.js using f32 operations.
  It does not introduce a normalized ray, barycentric epsilon or distance fudge.
- NormalOf14022d960 and native vector normalization are reused from the
  existing original-validated tile math. ASCII source faces compute their
  native planes; binary source faces retain their stored normal and constant.
- Binary mesh loader14007be10 copies serialized MaxFace records32 bytes each
  from node78/count7c into runtimeb0/b8 independently of render counts/index
  buffers. PartTriMesh::HitCheckGeom1400905b0 reads runtimeb0/b8, face vertex
  indices1a/1c/1e and plane0/0c before calling polyhit. The binary parser formerly
  retained only reconstructed render faces after optimized draw-list replacement.
  It now keeps nativeCollisionFaces before that replacement. buildMesh stores
  immutable source hit geometry on shared BufferGeometry, preserving original
  cached planes through object clones. Render geometry/materials stay unchanged.
- camera_scene_query now uses those source records and native polygon crossing.
  Explicitly empty original hit lists remain empty even if draw triangles exist.
  Authored Three-only fixtures have a geometry fallback using the same polygon
  primitive. Static scene membership and local transforms are still adapters.
- Existing loadAreaWalkmesh intentionally separated walkable and denied faces
  for movement, but the camera previously received only the walkable partition.
  It now additionally returns cameraTriangles containing both partitions.
  Network scene/camera consumes that separate collection; movement groundFaces,
  navigator data, canonical objects and server authority are unchanged. Native
  maskFFFFFFFFBFFFFFFF still excludes surface30 in camera AABB checks.
- Installed Prelude m0q1a:9 tiles,177 movement faces,509 camera faces including
 332 non-walkable faces, no unavailable WOKs. Installed model names/counts only
  are recorded in native-camera-polygon-installed-v1.json, not proprietary data.
  All6 sampled starting-room tile models have equal aggregate hit/draw counts;
  this sample does not demonstrate an optimized count mismatch. Separating the
  lists is required by the observed original storage/call path regardless.

Validation:

- inspect-native-camera-polygon.py executes complete original polyhit, including
  all arithmetic/branches and output writes; no called function is replaced
  inside polyhit. Cases cover front/back/coplanar/zero-length segments, inclusive
  edges/endpoints, several scales, output aliasing and256 randomized planes whose
  normals are computed by original NormalOf. Final oraclev1:1876 cases. JS hit
  decisions and each returned float bit agree. Plane normals/constants also
  agree for the256 original-generated randomized cases. This is finite synthetic
  input coverage, not proof for every exceptional IEEE value or CPU math profile.
- Polygon unit testv1 wrongly compared manually supplied axis-plane normals
  with a freshly computed signed-zero normal; that was an invalid plane-oracle
  assertion, not an observed polyhit mismatch. v2 restricts plane comparisons
  to actual native-generated normals; v3 adds installed-source/integration checks.
- Installed binary plc_a08 test traverses serialized nodes and checks every
  retained face's index/normal/constant bits against original bytes, before any
  draw reconstruction. Source records stay in memory; no resource copy is saved.
  Authored integration tests cover empty/different source vs draw geometry,
  non-walkable WOK coverage, surface30 filtering and unchanged movement partition.
- Final focused suitev1:118 PASS across camera/network/area/model regressions.
  Buildv1 PASS with the existing bundle-size warning. Isolated Electronv1 PASS:
 107 native camera command steps,105 location packets/116 frames, attachment
  routing/reversion and rendered-wall clear-view selection through the new
  polygon implementation. Canonical state unchanged, stderr empty.
- Built Prelude smokev1 reaches authored Pavel entry33/scriptMode1 without a
  dialogue error or stderr; screenshot inspected. It deliberately detaches the
  camera for dialogue picking; this is a rendering/shared-code regression test,
  not live camera acceptance or campaign completion.

Further research and limits:

- Full primary1407d2940/recovery1407d3840 continuous collision bodies are now
  retained as dedicated REA dossiers. They predict camera motion, use ordered
  bidirectional hit queries, cache collision distances/focus in globals, adjust
  distance limits, and recover with frame-time terms including3.5. They must
  not be approximated by a generic camera push-in. Not implemented here.
- Camera::MapToScreen140059a90 uses viewport HEIGHT divided by2*tan(viewAngle/2)
  for both screen axes. This supports the current vertical-FOV interpretation;
  it does not prove all native clipping, viewport/GUI scaling or render matrices.
  Camera::ViewVolumeSet14005cc00 is merely a flag getter, not frustum construction.
  SetViewPort14005b810 stores viewport fields with nonpositive dimensions->1.
- Native BSP registration, Part ownership/hit flags, hidden static geometry,
  native hierarchy/transform rounding, WOK renderer-vs-surface-loader snapping,
  animated/static classification and complete scene clipping still need audits.
  A bit-matched polygon function does not prove the whole scene query equivalent.
  SP automatic entry-search, remaining camera VM/flags, keyhole attachment
  semantics and concurrent original-client camera visual comparison remain open.
- User replacementv76 PID37376 and owned vanilla server PID20964 remain
  untouched. New build is not loaded in the open user client. Original game,
  Ghidra and installed resources were not modified; no credentials were used.

Sealed checkpoint: backups/multiplayer-native-camera-polygon-20261018-v1.zip,
13711 files/304713256 bytes, all entry lengths/SHA256 verified by writer36942,
terminal exit0 consumed. Scope audit:28 required files present,13712 entries
including manifest, zero forbidden assets/live-session/settings entries. The
first scope check used case-sensitive ZipArchive.GetEntry for the roadmap's
extension and falsely reported it missing; case-insensitive inventory confirmed
the Windows filename. Broad credential-shape audit13525 files:7 candidates in5
files, all unchanged from the prior safe checkpoint, zero new candidates. No
authentication/credential input occurred. This post-seal record is outside zip.
