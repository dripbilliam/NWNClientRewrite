# Native camera attachment — 2026-10-18

Full multiplayer goal remains ACTIVE. This implements received attachment
following/reversion; automatic find-clear-view search, collision recovery,
camera flags and remaining SP VM adapters still need work.
Read-only nwmain89.8193.37-17 SHA256:
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

Important correction to the preceding location notes: the object obtained
before module target124 changes is not a universal dummy. Machine code and
original execution show target ID in RDX survives app thunk1406abb60 into
1406d81f0 and CGameObjectArray::GetGameObject140296470. The thunk's decompiled
signature omitted that forwarded argument. Virtual18 obtains the client object
interface; virtual140(byte255,1) obtains that target's render object. No semantic
Ghidra renames or executable changes were made. The earlier dummy interpretation
was an inference and is superseded by this evidence.

Observed original owners:

- ExecuteCommandAttachCamera140510cf0 resolves the controlling client, substitutes
  the PC for OBJECT_INVALID, checks creature5/placeable9, same area and a known
  last-update object, then sends camera family16/subtype10 through1404d0bb0.
  Its payload is WriteOBJECTIDServer plus BOOL find-clear-view. Client reader
 1409737c0 copies the canonical client ID unchanged; it does not allocate IDs.
- Client attachment1407cf6f0 rejects missing object/interface/render object
  before changing target124 or find-clear-view140. It calls real
  Camera::SetFollow14005b4c0, which creates a new Follow140053da0. Gob::SetBehavior
 140094890 installs it and destroys the old behavior; there is no state transfer
  there. The attachment owner restores remembered distance/yaw/pitch when saved
  distance128 is nonzero and sets spring750.
- Constructor focus starts at render-object world position. Follow offset uses
  target creature appearance HEIGHT (minus.5 in top-down, minimum1), or1 for a
  placeable. Fresh Follow starts distance8/yaw0, while attachment replaces pitch
  with the current maximum pitch before restoring any remembered pose.
- Script lock globals survive attachment but their physical bounds are those
  of the new Follow when the attachment owner skips an unlocked-bound update:
  pitch0..360 and distance0..10. Yaw clamp also starts disabled. This surprising
  native behavior was executed rather than replaced with invented lock transfer.
- Native mode owners still read the controlled creature through1406ac1a0;
  following another object changes the position target, not control/possession
  or the controlled creature's facing used for chase steering. Changing mode
  uses PC height; attachment initialization itself uses target height.
- Installed nwscript AttachCamera contract confirms automatic return to the PC
  when the target is destroyed or the PC transitions areas. Attachments are not
  save-game state. These lifecycle rules are implemented in presentation only.

Implementation:

- Decoder16/10 -> current-session frontend queue -> NetworkPlayerCamera.receive.
  Known current-area creature/placeable render bindings are required. Invalid,
  missing, other-area and unsupported targets are ignored with a recorded
  network.camera-attachment-unavailable diagnostic, preserving the prior target.
- The controller creates native-equivalent Follow state, tracks remembered pose
  at the native pre-Follow point, and follows the displayed target position.
  Canonical object positions, IDs, control, ownership and gameplay are untouched.
  Target disappearance/area mismatch reattaches to the controlled PC. A temporary
  missing render binding during model replacement waits without treating a known
  canonical object as destroyed; this asynchronous renderer policy is an adapter
  choice, not a native model-replacement oracle.
- Area/session reset clears attachment state. Main area-load order now resets
  attachment before entry-camera focus so a former target's anchor cannot leak
  into the entry view while the new PC model is loading. Persistence of other
  camera commands across area transitions remains a separate native audit.
- A true find-clear-view request applies the target and native search-state
  gating, but emits network.camera-clear-view-unhandled. Search is not implemented
  and is not silently claimed complete. Ordinary mode/script transition updates
  are skipped while that native search state is set. User input/clear-view edge
  behavior and attachment-aware keyholing still need broader verification.

Original-code validation:

- inspect-native-camera-attachment.py executes full attachment, actual ID-lookup
  thunks, SetFollow and Follow constructor. Object-table lookup, interface/render
  accessors, dependency/safe-pointer bookkeeping, behavior installation/destruction,
  active-PC lookup and render invalidation are explicit lower boundaries.
- Final oraclev6:216 state cases and10 actual native sender bodies. Three modes,
  creature/placeable, two heights, cached/no-cached pose, both find-clear values,
  pitch/distance lock combinations, missing objects/interfaces/render targets,
  old target IDs and return-to-PC paths are covered. Original state agrees with
  the JS initializer. Native sender bodies decode with exact canonical IDs/BOOL.
- Oraclev1/v2 failed a synthetic app-manager indirection; v3 exposed an excluded
  final constructor instruction. v4 fixed verified inclusive ranges; v5 added
  native sender bodies; v6 admits the exact verified sender range. Only final
  observations are acceptance evidence. The leaf-disassembly helper now supports
  instruction windows without claiming a PE unwind boundary; v1 failed on the
  valid leaf thunk, v2 shows its register forwarding.
- Final229 affected tests PASSv3; buildv2 PASS with the existing bundle warning.
  Actual-wire movement/camera regressions remain included. Tests cover rendered
  target movement, controlled-PC steering/height, canonical invariants, destruction
  reversion, model replacement wait, diagnostics and area/session reset.
- Isolated Electron fixturev1 routes a real native body through the production
  frontend, follows rendered target movement, preserves canonical objects/control,
  and reverts after target removal. Earlier107 command/105 location-packet checks
  still pass, location playback reaches its endpoint in116 frames, empty stderr.
  This is not new live vanilla-server attachment acceptance evidence.
- Built Prelude smokev1 retains authored Pavel entry33/scriptMode1 with no
  dialogue error and empty stderr. It intentionally uses a detached model-preview
  camera and disabled startup; it is not an attachment/campaign-completion test.
  The final build's subsequent main-only change resets the MP camera before entry
  focus; no later shared/SP controller change was made.

The exploratory query camera-attachment-frame-validation at1407d1690 instead
describes combat/target-framing logic and is not attachment-destruction proof.
The guessed set-behavior-inner query14005cc30 is unused. No conclusions depend
on either misleading exploratory filename. Current callback/search behavior
remains incomplete and explicitly diagnosed.

Userclientv76 PID37376 and ownedserver20964 are untouched while testing. This
updated attachment build is not loaded into that session. Full multiplayer
completion still requires the original-client coexistence/gameplay gates.

Final process check confirms client37376/server20964 remain live. Screenshot
from the built Prelude regression was inspected. Credential audit13,450
source/evidence/build text files: private credential hits0.

Checkpoint multiplayer-native-camera-attachment-20261018-v1.zip sealed; every
entry length/SHA256 verified:13,634 files/300,549,342 bytes. Scope26 required
present/forbidden0;13,635 entries including manifest. Writer21208 terminal0
consumed. Scope audit and this postseal note remain outside the sealed archive.
