# Native continuous camera collision — 2026-10-18

Full multiplayer goal remains ACTIVE. This implements the original default
continuous collision/recovery algorithms and their known camera flags. Exact
BSP registration/transforms, alternate configuration and original-client visual
acceptance remain incomplete. Original nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
All original code/resources/Ghidra were research-only inputs.

Native owners and behavior:

- Input update1406e6220 runs mode/script camera updates1407d0860, then collision
 1407d07d0 when keyholing is inactive OR disable-camera-collisions is false OR
  module flag1 forces it. Dispatcher skips when find-clear-view140 or flag2
  is set; mode2 selects1407d3840, modes0/1 select1407d2940. This is why a generic
  every-frame push-in would differ from ordinary original gameplay.
- Both original routines take delta time in XMM1 and wheel/key zoom rate in
  XMM2, return FLOAT in XMM0. Decompiled CONCAT44 return descriptions are not
  a uint64 protocol value; actual ABI/instructions were checked. The oracle
  reads XMM0, not the scalar writer helper's unrelated RAX return.
- Collision obtains current camera position, CONTROLLED PC position38 plus
  camera offset118, and PC render eligibility1407cebd0 (object78, virtual10
  with byte255). Following another object does not replace this controlled-PC
  collision input. Missing render eligibility or disabled global leaves the
  input rate unchanged.
- Prediction uses current raw pose, camera quaternion, current angular inputs,
  wheel rate, effective global pitch/distance bounds and spring750. Its cached
  focus is independent of actual Follow focus and targets PC position+[0,0,1],
  rather than the Follow appearance height. Primary globals1414272c4/c8 and
  stiff1414272d4/d8 hold separate requested distance/focus histories.
- Primary checks ordered bidirectional static-scene segments, with a separate
  negative/zoom-out path reaching the maximum distance. Stiff starts with the
  PC-to-predicted-camera segment. Both use native front-face polygon semantics,
  hit-point offsets0.001, saved requested distance, clamp-state updates and
  recovery terms(current+(saved-current)*3.5*dt). Primary recovery uses its
  original0.0001 tolerance; stiff recovery does not add that tolerance.
- Native long sequence at dt.016 restores modes0/1 to20/cache0. Stiff reaches
 19.999984741210938/cache20 and stalls at f32 precision. That tiny residual is
  original behavior, preserved rather than replaced with an invented snap.
- Pin reads confirm collision-enable14129740c=1, clamp-enable141296fac=1 and
  alternate query1414272c0=0. The nondefault alternate path calls1407da6d0
  instead of Scene::HitCheck; it is not implemented by this milestone.
- Zoom setter1407d4340 adds to existing Follow speed4c (which may contain a
  timed-script rate), records module158 and respects flag64. Input update only
  applies a nontrivial external rate. Timed script zoom also uses this setter.
  Keyboard zoom now enters that same external-rate/collision path; browser key
  bindings remain an adapter rather than imported native control settings.
- Received camera16/12 reads signed INT32 and directly stores module2bc. Storage
  now routes through the current-session frontend. Known bits1/2/64 affect
  collision/zoom; other bits are retained and explicitly diagnosed once per
  command as network.camera-flags-partial. This is not complete flag semantics.

Implementation:

- camera_collision.js implements both verified routines with f32 arithmetic,
  separate histories, ordered query callbacks, native clamp/writeback behavior
  and original saved-distance rules. It operates on presentation state only.
- camera_scene_query.nearest clips each segment against source hit geometry
  and returns a hit point. The bool clear-view API remains available. Native
  polygon math/cached binary planes are reused from the preceding milestone.
  Query geometry is cached with the area presentation; current world matrices
  are refreshed when needed. Exact BSP traversal/membership is still an adapter.
- GameCamera calls collision after steering/script updates, before external
  zoom accumulation and actual Follow integration. Script speed and wheel speed
  remain distinct; known zoom-block flag applies to both setter paths. A pending
  clear-view request skips continuous collision in its native ordering.
- Network camera supplies displayed controlled-PC position/render eligibility,
  preserves server/canonical state and follows the existing attachment target.
  Main explicitly supplies active installed-shader keyholing state. Default
  standalone settings reflect native enabled keyholing; missing shader falls
  back to collision in this renderer. Native configuration import/GPU-capability
  negotiation is not fully recreated by that fallback policy.
- SP uses the same collision controller and source area geometry when needed,
  gated during asynchronous area loading/transition. Automatic SP clear-view
  entry wiring, complete camera VM adapters and all mode/session/configuration
  lifecycle details still need separate work.

Validation and corrections:

- inspect-native-camera-collision.py executes full dispatcher and both original
  algorithms, including prediction math, branch order, saved distance, Follow
  writes and FLOAT return. Synthetic camera/PC virtual accessors, eligibility,
  CHitInfo bookkeeping and controlled ray-result/point matrices are explicit
  lower boundaries. No original game process was patched or injected.
- Final oraclev3:891 cases/1866 steps. Covers all3 modes,3 frame deltas, both
  zoom directions/no zoom,16 ray-result masks, cached/no-cached distance, disabled
  collision/clamp/eligibility, pending clear-view, bypass flag, out-of-limit pose,
  moving PC and321-frame recovery sequences. JS query endpoints, caches, clamps,
  distances and rate returns agree within0.000025; this is not a claim that
  every collision float bit or arbitrary scene/input has been proven equivalent.
- Oraclev1 omitted explicit settings-mode initialization and is not acceptance
  evidence. v2 fixes mode initialization; v3 adds native long recovery evidence.
  Initial JS reversed the first negative-zoom segment; original execution exposed
  and corrected that error. An initial integrated test expected exact stiff
  recovery/cache reset; long native execution disproved that expectation.
- Final focused suitev4:124 PASS, including native camera commands/flags,
  steering, location, attachment, polygon, collision, keyhole, captured concurrent
  multiplayer movement, network scene/session/resources and area/model data.
  Default-keyhole gating was corrected after v1 exposed an unintended activation
  in the standalone captured-wire fixture. Production already passes explicit
  shader state. Buildv2 PASS, existing bundle-size warning only.
- Final isolated Electronv3 PASS:107 earlier native command steps,105 location
  packets/116 frames, attachment/reversion, clear-view and all3 continuous
  collision/recovery paths using a real native flag1 packet and production
  NetworkPlayerCamera/static geometry. Canonical objects/control unchanged,
  no unexpected diagnostics, empty stderr. WebGL renders the recovered anchor;
  screenshot inspected. v1 failed stale/default query initialization and is
  superseded by v2/v3. This is not a live server/original-client camera test.
- Built Prelude SP smokev1 retains authored Pavel entry33/scriptMode1, no dialogue
  error, empty stderr, screenshot inspected. It detaches for dialogue picking,
  so this is regression evidence, not active SP collision acceptance.
- Interactive replacementv76 PID37376 and owned vanilla server PID20964 remain
  live and untouched. The new build is NOT loaded in the user session. No new
  authentication or credentials were used.

Remaining requirements include exact native BSP/Part registration and hierarchy
transform rounding, WOK renderer/surface-loader differences, alternate ray mode,
configuration persistence, other camera flags/VMs, SP entry search, attachment
keyhole semantics, and actual concurrent original-client visual comparisons.
The broader multiplayer gameplay objective is not complete.

Sealed checkpoint: backups/multiplayer-native-camera-collision-20261018-v1.zip,
13749 files/305687018 bytes; writer46122 finished exit0, every entry length
and SHA256 verified, terminal handle consumed. Scope audit35 required files
present,13750 entries with manifest, zero forbidden assets/live-session/settings
entries. Broad credential-shape audit13560 files:7 candidates in5 files, all
unchanged from the previous safe polygon checkpoint, zero new candidates.
No new authentication/credentials occurred. This post-seal note is outside zip.
