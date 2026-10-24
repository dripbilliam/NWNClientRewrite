# Native atmosphere investigation — work in progress

This historical research note is superseded by the partial verified port in
[NATIVE-ATMOSPHERE.md](NATIVE-ATMOSPHERE.md). Its original open questions below
are retained as investigation history, not current implementation status.
The preceding lighting/picking checkpoint is `NATIVE-LIGHTING-PORTALS.md`. Original target
NWN:EE89.8193.37-17 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
All analysis is read-only; no game-server connection or live process modification.

Retained REA function dossiers are `reports/native-fog-methods-v1.json` and
`reports/native-fog-camera-getters-v1.json`. Capstone candidate use-site scan,
including PE unwind owners, is `reports/native-fog-amount-sites-v1.json`;
`tools/inspect-native-fog-sites.py` reproduces it without executing the binary.
Unwind owners can be fragments, not full semantic entry points. The displacement
scan alone does not establish that every occurrence refers to the area.

Verified function observations:

* Base `CNWArea::SetFog` at `140299120` stores RGB at88/8c/90 and a byte at94.
* Client override `1407e5850` stores the full amount as float310 and the byte94,
  calls `mainscene.fogcolor` and **SetClearColor with that same RGB**. Merely
  copying Three's constant background cannot reproduce the native fog horizon.
* Amount-only update `1407e5990` changes310/94 and reissues the current fog color.
* Module update `1407cffc0`, relevant assembly `1407d0159..1407d029b`, obtains
  camera near/far clip, uses area FogClipDist108, camera distance and amount310,
  then calls scene virtual88 (SetFogRange). Its ordinary non-null-area branch:
  end = FogClipDist unless end <= near, then end = near + .01;
  start = (camera distance - amount) + 10;
  if start >= end, start = end - 1.01.
  These operation boundaries use single-precision instructions. Negative starts
  are possible; do not silently clamp them without investigating presentation.
* The same block sets camera far clip to max(end,45), adding90 when the settings
  flag68 and area skybox bytee0 are both nonzero. This is not yet a ported native
  culling policy. Exceptional null-area/decompiler paths remain unimplemented.
* `Camera::GetClipDist` at140058ca0 reads4d0/4d4. `Camera::GetDist`140058cc0
  returns behavior48 when a behavior exists and its virtual40 succeeds, else0.
  Their original vtable entries140d82e80/140d82ec8 agree with slots78/c0 used
  by the module update. Native camera core already stores the behavior distance.
* `Scene::SetFogRange`1400d3360 stores144/148. `Scene::DoFog`1400c7f10 enables
  fog when140 is nonzero, supplies RGB14c and the range to renderer modes0/1.
  `GLRender::SetFogModef`1400b6fc0 caches those values/invalidation counters.

The day/night interpolator1407e90b0, already retained under
`backups/animations/rea-arelith-native-area-lighting-profile-v1.json`, blends
ambient/diffuse/fog RGB and fog amount through transition progress, not the
preview rule of selecting whichever period has nonzero colors. Fixed-night
areas, dawn/dusk interpolation, timing updates and the corresponding native
setter should be integrated together. The original area message carries sun/
moon fog colors/amounts, FogClipDist, day/night flags and module time; no guessed
per-area preset is needed.

Next verification: execute the bounded original range block with explicit
camera/scene getter stubs; compare single-precision range cases; confirm shader
depth convention/negative starts; then port native environment state, dynamic
updates and solid fog-color background. Godot4.7's official environment header
supports FOG_MODE_DEPTH and begin/end/curve, but that alone does not establish
identical shader semantics. Skybox art/animation, weather and particle fog
remain separate migration requirements. No performance acceptance is implied.
